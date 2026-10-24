#!/bin/bash
set -e

echo "=========================================================="
echo "🔧 УСТАНОВКА TV_FIX_VPN (Мост Mihomo ↔ Zalp для Smart TV)"
echo "=========================================================="

# ============================================================
# ШАГ 1: Очистка старых версий
# ============================================================
echo "[1/6] Очистка предыдущих установок..."
rm -f /usr/local/bin/fix
rm -f /usr/local/bin/tv_fix_vpn.sh
iptables -t nat -D PREROUTING -j TV_VPN_FIX 2>/dev/null || true
iptables -t mangle -D PREROUTING -j TV_VPN_FIX 2>/dev/null || true
iptables -t nat -F TV_VPN_FIX 2>/dev/null || true
iptables -t nat -X TV_VPN_FIX 2>/dev/null || true
iptables -t mangle -F TV_VPN_FIX 2>/dev/null || true
iptables -t mangle -X TV_VPN_FIX 2>/dev/null || true
(crontab -l 2>/dev/null | grep -v "tv_fix_vpn\|fix watchdog") | crontab -
echo "   ✅ Старые правила и файлы удалены."

# ============================================================
# ШАГ 2: Добавление tproxy-port в конфиг Mihomo (если нет)
# ============================================================
echo "[2/6] Настройка Mihomo для TPROXY-перехвата..."
if ! grep -q "^tproxy-port:" /etc/mihomo/config.yaml 2>/dev/null; then
    # Вставляем tproxy-port после mixed-port
    sudo sed -i '/^mixed-port:/a tproxy-port: 7892' /etc/mihomo/config.yaml
    echo "    Добавлен tproxy-port: 7892 в конфиг Mihomo."
    sudo systemctl restart mihomo
    sleep 3
    echo "    Mihomo перезапущен с новым портом."
else
    echo "   ✅ tproxy-port уже настроен."
fi

# Проверка, что порт слушается
if ss -tlnp | grep -q ":7892 "; then
    echo "   ✅ Порт 7892 (TPROXY) активен."
else
    echo "   ⚠️  Порт 7892 не слушается. Проверь: sudo mihomo-test"
fi

# ============================================================
# ШАГ 3: Создание основного скрипта /usr/local/bin/fix
# ============================================================
echo "[3/6] Создание команды 'fix'..."

cat << 'FIXEOF' > /usr/local/bin/fix
#!/bin/bash
# ==========================================================
# TV_FIX_VPN — Мост Mihomo ↔ Zalp для Smart TV
# Использование: fix {start|stop|restart|test}
# ==========================================================

# --- КОНФИГУРАЦИЯ ---
TV_MAC_1="74:E6:B8:06:CD:8A"    # LG WebOS (тестовый)
TV_MAC_2="04:B9:E3:4A:3C:EC"    # Samsung Tizen 1 (заглушка)
TV_MAC_3=""                     # Samsung Tizen 2 (заглушка)

MIHOMO_PORT="7890"
TPROXY_PORT="7892"
DNS_PORT="1053"
CHAIN="TV_VPN_FIX"
LOG="/var/log/tv_fix_vpn.log"

# --- ФУНКЦИИ ---

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') — $1" | tee -a "$LOG"
}

check_mihomo() {
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" -x "http://127.0.0.1:$MIHOMO_PORT" \
           http://www.gstatic.com/generate_204 -m 5 2>/dev/null)
    [ "$code" = "204" ] || [ "$code" = "200" ]
}

is_active() {
    iptables -t nat -L PREROUTING -n 2>/dev/null | grep -q "$CHAIN"
}

do_start() {
    if is_active; then
        log_msg "️  TV_FIX_VPN уже активен."
        return 0
    fi

    if ! check_mihomo; then
        log_msg " Mihomo не отвечает. Старт отменён — трафик остаётся на Zalp."
        return 1
    fi

    # Создаём цепочки
    iptables -t nat -N $CHAIN 2>/dev/null || iptables -t nat -F $CHAIN
    iptables -t mangle -N $CHAIN 2>/dev/null || iptables -t mangle -F $CHAIN

    local macs=("$TV_MAC_1" "$TV_MAC_2" "$TV_MAC_3")
    local count=0

    for mac in "${macs[@]}"; do
        [ -z "$mac" ] && continue

        # MANGLE: блокируем QUIC и DoH ДО того, как они уйдут дальше
        iptables -t mangle -A $CHAIN -m mac --mac-source $mac -p udp --dport 443 -j DROP
        iptables -t mangle -A $CHAIN -m mac --mac-source $mac -p tcp --dport 853 -j DROP
        iptables -t mangle -A $CHAIN -m mac --mac-source $mac -p udp --dport 853 -j DROP

        # MANGLE: TPROXY для всего TCP (кроме 853, который уже дропнули выше)
        iptables -t mangle -A $CHAIN -m mac --mac-source $mac -p tcp \
            -j TPROXY --on-port $TPROXY_PORT --tproxy-mark 0x1/0x1

        # MANGLE: ACCEPT — чтобы пакет НЕ дошёл до NFQWS (Zalp)
        iptables -t mangle -A $CHAIN -m mac --mac-source $mac -j ACCEPT

        # NAT: перенаправляем DNS на Mihomo
        iptables -t nat -A $CHAIN -m mac --mac-source $mac -p udp --dport 53 \
            -j REDIRECT --to-port $DNS_PORT

        log_msg "✅ Правила добавлены для MAC: $mac"
        ((count++))
    done

    # Вставляем цепочки в самое начало PREROUTING (приоритет над Zalp/NFQWS)
    iptables -t mangle -I PREROUTING 1 -j $CHAIN
    iptables -t nat -I PREROUTING 1 -j $CHAIN

    # Маршруты для TPROXY (обязательны — без них ядро дропает пакеты)
    ip rule add fwmark 0x1 table 100 2>/dev/null || true
    ip route add local default dev lo table 100 2>/dev/null || true

    log_msg "🟢 TV_FIX_VPN АКТИВИРОВАН для $count устройств. Трафик ТВ → VPN."
    echo "🟢 TV_FIX_VPN активен. Трафик телевизоров идёт через Mihomo VPN."
}

do_stop() {
    if ! is_active; then
        log_msg "ℹ️  TV_FIX_VPN уже неактивен."
        echo " TV_FIX_VPN неактивен. Трафик ТВ обрабатывается Zalp."
        return 0
    fi

    iptables -t nat -D PREROUTING -j $CHAIN 2>/dev/null
    iptables -t mangle -D PREROUTING -j $CHAIN 2>/dev/null
    iptables -t nat -F $CHAIN 2>/dev/null
    iptables -t nat -X $CHAIN 2>/dev/null
    iptables -t mangle -F $CHAIN 2>/dev/null
    iptables -t mangle -X $CHAIN 2>/dev/null

    ip rule del fwmark 0x1 table 100 2>/dev/null || true
    ip route del local default dev lo table 100 2>/dev/null || true

    log_msg "🔴 TV_FIX_VPN ОТКЛЮЧЁН. Трафик ТВ делегирован обратно Zalp."
    echo "🔴 TV_FIX_VPN отключён. Трафик ТВ вернулся к Zalp."
}

do_restart() {
    log_msg " Перезапуск TV_FIX_VPN..."
    do_stop
    sleep 1
    do_start
}

do_test() {
    echo "=========================================================="
    echo "🔍 ДИАГНОСТИКА TV_FIX_VPN"
    echo "=========================================================="

    # 1. Статус патча
    if is_active; then
        echo "🟢 TV_FIX_VPN: АКТИВЕН"
    else
        echo " TV_FIX_VPN: НЕАКТИВЕН (трафик ТВ → Zalp)"
    fi

    # 2. Статус Mihomo
    echo ""
    echo "── Mihomo ──"
    if systemctl is-active --quiet mihomo; then
        echo "✅ Сервис Mihomo: активен"
    else
        echo "❌ Сервис Mihomo: неактивен"
    fi

    if check_mihomo; then
        echo "✅ Прокси Mihomo: отвечает"
    else
        echo "❌ Прокси Mihomo: не отвечает"
    fi

    local node
    node=$(curl -s http://127.0.0.1:9090/proxies/AUTO-FASTEST 2>/dev/null \
           | grep -o '"now":"[^"]*"' | cut -d'"' -f4)
    [ -n "$node" ] && echo "   Активный узел: $node"

    # 3. Порты
    echo ""
    echo "── Порты ──"
    for p in 7890 7892 1053; do
        if ss -tlnp | grep -q ":$p "; then
            echo "✅ Порт $p: слушается"
        else
            echo "❌ Порт $p: НЕ слушается"
        fi
    done

    # 4. Правила iptables
    echo ""
    echo "── Правила iptables (TV_VPN_FIX) ──"
    iptables -t nat -L $CHAIN -n -v 2>/dev/null || echo "   (цепочка nat не создана)"
    echo ""
    iptables -t mangle -L $CHAIN -n -v 2>/dev/null || echo "   (цепочка mangle не создана)"

    # 5. Маршруты TPROXY
    echo ""
    echo "── Маршруты TPROXY ──"
    ip rule list | grep "0x1" || echo "   (правило fwmark 0x1 отсутствует)"
    ip route show table 100 2>/dev/null || echo "   (таблица 100 пуста)"

    # 6. Список ТВ
    echo ""
    echo "── Зарегистрированные устройства ──"
    local i=1
    for mac in "$TV_MAC_1" "$TV_MAC_2" "$TV_MAC_3"; do
        if [ -n "$mac" ]; then
            echo "   ТВ#$i: $mac ✅"
        else
            echo "   ТВ#$i: (не настроен)"
        fi
        ((i++))
    done

    echo "=========================================================="
}

# --- ТОЧКА ВХОДА ---
case "$1" in
    start)   do_start ;;
    stop)    do_stop ;;
    restart) do_restart ;;
    test)    do_test ;;
    watchdog)
        # Для cron: автопереключение при падении/восстановлении Mihomo
        if is_active; then
            if ! check_mihomo; then
                log_msg "⚠️  Mihomo упал — отключаю TV_FIX_VPN (fallback на Zalp)"
                do_stop
            fi
        else
            if check_mihomo; then
                log_msg "✅ Mihomo восстановлен — включаю TV_FIX_VPN"
                do_start
            fi
        fi
        ;;
    *)
        echo "Использование: fix {start|stop|restart|test}"
        echo ""
        echo "  start   — перехватить трафик ТВ через VPN"
        echo "  stop    — вернуть трафик ТВ к Zalp"
        echo "  restart — перезапустить патч"
        echo "  test    — полная диагностика"
        exit 1
        ;;
esac
FIXEOF

chmod +x /usr/local/bin/fix
echo "   ✅ Команда 'fix' установлена в /usr/local/bin/fix"

# ============================================================
# ШАГ 4: Watchdog в cron (каждые 3 минуты)
# ============================================================
echo "[4/6] Установка watchdog (авто-fallback при сбое VPN)..."
(crontab -l 2>/dev/null | grep -v "fix watchdog") | crontab -
(crontab -l 2>/dev/null; echo "*/3 * * * * /usr/local/bin/fix watchdog >/dev/null 2>&1") | crontab -
echo "   ✅ Watchdog установлен (проверка каждые 3 минуты)."

# ============================================================
# ШАГ 5: Первичный запуск и тест
# ============================================================
echo "[5/6] Первичный запуск..."
fix start

echo ""
echo "[6/6] Диагностика..."
fix test

echo ""
echo "=========================================================="
echo "✅ УСТАНОВКА TV_FIX_VPN ЗАВЕРШЕНА"
echo "=========================================================="
echo ""
echo "Доступные команды:"
echo "  fix start    — включить перехват ТВ через VPN"
echo "  fix stop     — отключить, вернуть трафик к Zalp"
echo "  fix restart  — перезапустить патч"
echo "  fix test     — диагностика"
echo ""
echo "Лог: /var/log/tv_fix_vpn.log"
echo "=========================================================="
