#!/bin/bash
echo "🗑️ Полное удаление TV_FIX_VPN..."

# 1. Остановка и очистка правил iptables
echo "[1/5] Очистка правил iptables..."
iptables -t nat -D PREROUTING -j TV_VPN_FIX 2>/dev/null || true
iptables -t mangle -D PREROUTING -j TV_VPN_FIX 2>/dev/null || true

# 2. Удаление цепочек TV_VPN_FIX
echo "[2/5] Удаление цепочек TV_VPN_FIX..."
iptables -t nat -F TV_VPN_FIX 2>/dev/null || true
iptables -t nat -X TV_VPN_FIX 2>/dev/null || true
iptables -t mangle -F TV_VPN_FIX 2>/dev/null || true
iptables -t mangle -X TV_VPN_FIX 2>/dev/null || true

# 3. Очистка маршрутов TPROXY
echo "[3/5] Удаление маршрутов TPROXY..."
ip rule del fwmark 0x1 table 100 2>/dev/null || true
ip route del local default dev lo table 100 2>/dev/null || true

# 4. Удаление команды fix и скриптов
echo "[4/5] Удаление команды 'fix'..."
rm -f /usr/local/bin/fix
rm -f /usr/local/bin/tv_fix_vpn.sh

# 5. Удаление watchdog из cron
echo "[5/5] Удаление watchdog из cron..."
(crontab -l 2>/dev/null | grep -v "fix watchdog" | grep -v "tv_fix_vpn") | crontab -

# Удаление лог-файла
rm -f /var/log/tv_fix_vpn.log

echo ""
echo "✅ TV_FIX_VPN полностью удален."
echo "   - Правила iptables очищены"
echo "   - Маршруты TPROXY удалены"
echo "   - Команда 'fix' удалена"
echo "   - Watchdog отключен"
echo ""
echo "ℹ️  Трафик телевизоров теперь обрабатывается Zalp."
echo "ℹ️  Mihomo продолжает работать независимо (для ручного использования)."
