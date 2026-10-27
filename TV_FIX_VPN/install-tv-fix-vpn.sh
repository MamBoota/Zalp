#!/bin/bash
set -e

echo "=========================================================="
echo "🔧 УСТАНОВКА TV_FIX_VPN (Чтение из /opt/zalp/tv_macs.conf)"
echo "=========================================================="

MAC_FILE="/opt/zalp/tv_macs.conf"
if [ ! -f "$MAC_FILE" ]; then
    echo "⚠️ Файл $MAC_FILE не найден. Создаю шаблон."
    echo -e 'SERVER_IP="192.168.10.100"\n\n74:E6:B8:06:CD:8A\n04:B9:E3:4A:3C:EC' > "$MAC_FILE"
fi

# Очистка старых версий
echo "[1/5] Очистка предыдущих установок..."
rm -f /usr/local/bin/fix
iptables -t nat -D PREROUTING -j TV_VPN_FIX 2>/dev/null || true
iptables -t mangle -D PREROUTING -j TV_VPN_FIX 2>/dev/null || true
iptables -t nat -F TV_VPN_FIX 2>/dev/null || true
iptables -t nat -X TV_VPN_FIX 2>/dev/null || true
iptables -t mangle -F TV_VPN_FIX 2>/dev/null || true
iptables -t mangle -X TV_VPN_FIX 2>/dev/null || true

echo "[2/5] Настройка Mihomo (tproxy-port)..."
if ! grep -q "^tproxy-port:" /etc/mihomo/config.yaml 2>/dev/null; then
    sed -i '/^mixed-port:/a tproxy-port: 7892' /etc/mihomo/config.yaml
    systemctl restart mihomo
    sleep 2
fi

echo "[3/5] Создание динамического скрипта управления 'fix'..."
cat << 'FIXEOF' > /usr/local/bin/fix
#!/bin/bash
# TV_FIX_VPN — Динамический мост Mihomo ↔ Zalp
# Читает MAC-адреса из /opt/zalp/tv_macs.conf

MAC_FILE="/opt/zalp/tv_macs.conf"
[ ! -f "$MAC_FILE" ] && { echo "Нет файла $MAC_FILE"; exit 1; }

# Автоопределение IP сервера, если не задан в конфиге
SERVER_IP=$(grep -E '^SERVER_IP=' "$MAC_FILE" | cut -d'"' -f2)
if [ -z "$SERVER_IP" ] || [ "$SERVER_IP" == "auto" ]; then
    SERVER_IP=$(ip -4 addr show $(ip route | grep default | awk '{print $5}') | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
fi

apply_rules() {
    echo "Применение правил для TV Fix..."
    iptables -t mangle -F TV_VPN_FIX 2>/dev/null || iptables -t mangle -N TV_VPN_FIX
    iptables -t nat -F TV_VPN_FIX 2>/dev/null || iptables -t nat -N TV_VPN_FIX

    # === КРИТИЧНО: Создаем policy routing для TPROXY ===
    # Удаляем старые правила (если есть) и создаем заново
    ip rule del fwmark 0x1 lookup 100 2>/dev/null || true
    ip route flush table 100 2>/dev/null || true
    
    # Создаем таблицу маршрутизации 100
    ip route add local 0.0.0.0/0 dev lo table 100
    
    # Добавляем правило: пакеты с fwmark 0x1 идут в таблицу 100
    ip rule add fwmark 0x1 lookup 100
    
    echo "  ✓ Policy routing настроен (fwmark 0x1 → table 100)"
    # =========================================================

    # Читаем конфиг построчно
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" || "$line" =~ ^SERVER_IP= ]] && continue
        
        mac_upper=$(echo "$line" | tr 'a-z' 'A-Z' | tr -d '\r')
        [ -z "$mac_upper" ] && continue

        # Валидация формата MAC-адреса
        if [[ ! "$mac_upper" =~ ^([0-9A-F]{2}:){5}[0-9A-F]{2}$ ]]; then
            echo "    ⚠️ Пропуск некорректного MAC: $line"
            continue
        fi

        echo "  ↳ Настройка для MAC: $mac_upper"

        # 1. Блокировка обходных путей (QUIC, DoH)
        iptables -t mangle -A TV_VPN_FIX -p udp -m mac --mac-source "$mac_upper" --dport 443 -j DROP
        iptables -t mangle -A TV_VPN_FIX -p tcp -m mac --mac-source "$mac_upper" --dport 853 -j DROP
        iptables -t mangle -A TV_VPN_FIX -p udp -m mac --mac-source "$mac_upper" --dport 853 -j DROP

        # 2. Перехват DNS (UDP 53) → Mihomo (1053)
        iptables -t nat -A TV_VPN_FIX -p udp -m mac --mac-source "$mac_upper" --dport 53 -j DNAT --to-destination $SERVER_IP:1053

        # 3. Прозрачный прокси (TPROXY) для TCP
        iptables -t mangle -A TV_VPN_FIX -p tcp -m mac --mac-source "$mac_upper" -j TPROXY --on-port 7892 --on-ip 0.0.0.0 --tproxy-mark 0x1/0x1

        # 4. ACCEPT: изоляция от Zalp
        iptables -t mangle -A TV_VPN_FIX -m mac --mac-source "$mac_upper" -j ACCEPT

    done < "$MAC_FILE"

    # Гарантируем позицию TV_VPN_FIX
    while iptables -t mangle -D PREROUTING -j TV_VPN_FIX 2>/dev/null; do :; done
    iptables -t mangle -I PREROUTING 1 -j TV_VPN_FIX
    
    while iptables -t nat -D PREROUTING -j TV_VPN_FIX 2>/dev/null; do :; done
    iptables -t nat -I PREROUTING 1 -j TV_VPN_FIX

    echo "✅ Правила TV Fix применены. Трафик изолирован от Zalp."
}

remove_rules() {
    echo "Отключение TV Fix..."
    iptables -t mangle -D PREROUTING -j TV_VPN_FIX 2>/dev/null || true
    iptables -t nat -D PREROUTING -j TV_VPN_FIX 2>/dev/null || true
    iptables -t mangle -F TV_VPN_FIX 2>/dev/null || true
    iptables -t nat -F TV_VPN_FIX 2>/dev/null || true
    
    # Удаляем policy routing
    ip rule del fwmark 0x1 lookup 100 2>/dev/null || true
    ip route flush table 100 2>/dev/null || true
    
    echo "✅ Правила TV Fix и policy routing удалены."
}

case "$1" in
    start) apply_rules ;;
    stop) remove_rules ;;
    restart) remove_rules; sleep 1; apply_rules ;;
    test) 
        echo "=== Статус TV_VPN_FIX ==="
        iptables -t mangle -L TV_VPN_FIX -n -v
        echo "=== Статус NAT (DNS) ==="
        iptables -t nat -L TV_VPN_FIX -n -v
        ;;
    *) echo "Использование: fix {start|stop|restart|test}" ;;
esac
FIXEOF

chmod +x /usr/local/bin/fix

echo "[4/5] Настройка Watchdog (автозапуск)..."
(crontab -l 2>/dev/null | grep -v "fix watchdog") | crontab -
(crontab -l 2>/dev/null; echo "*/3 * * * * /usr/local/bin/fix start >/dev/null 2>&1") | crontab -

echo "[5/5] Первичный запуск..."
/usr/local/bin/fix start

echo "=========================================================="
echo "✅ TV Fix VPN успешно установлен и изолирован от Zalp!"
echo "   Для изменения MAC-адресов отредактируйте: /opt/zalp/tv_macs.conf"
echo "   Затем выполните: sudo fix restart"
echo "=========================================================="