#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║           Zalp Restore v5.0 (Hot Swap)               ║
# ║     Полная очистка + переустановка (без разрыва)     ║
# ╚══════════════════════════════════════════════════════╝
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Zalp Restore v5.0 (Hot Swap)               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Запускать только через sudo${NC}"
    exit 1
fi

find_traces() {
    local traces=0
    [ -d /opt/zalp ] && ((traces++))
    [ -x /opt/zalp/binaries/my/nfqws ] 2>/dev/null && ((traces++))
    [ -f /etc/systemd/system/nfqws.service ] && ((traces++))
    [ -x /usr/local/bin/zalp ] && ((traces++))
    [ -d /opt/mihomo ] && ((traces++))
    [ -f /etc/mihomo/config.yaml ] && ((traces++))
    iptables -t mangle -L 2>/dev/null | grep -q "TV_VPN_FIX" && ((traces++))
    echo $traces
}

echo -e "${YELLOW}[1/4] Поиск следов установки...${NC}"
TRACES=$(find_traces)
if [ "$TRACES" -eq 0 ]; then
    echo -e "${YELLOW}  Следов установки не найдено. Запускаем чистую установку...${NC}"
    SKIP_CLEANUP=1
else
    echo -e "${GREEN}  ✓ Найдено $TRACES следов установки${NC}"
    SKIP_CLEANUP=0
fi

if [ "$SKIP_CLEANUP" -eq 0 ]; then
    echo -e "${YELLOW}[2/4] Горячее отключение модулей (без разрыва интернета)...${NC}"
    
    # Отключение DPI
    iptables -t mangle -F PREROUTING 2>/dev/null || true
    iptables -t mangle -F OUTPUT 2>/dev/null || true
    ip6tables -t mangle -F PREROUTING 2>/dev/null || true
    systemctl stop nfqws 2>/dev/null || true

    # Отключение TV Fix
    if command -v fix &> /dev/null; then
        fix stop 2>/dev/null || true
    fi
    iptables -t mangle -F TV_VPN_FIX 2>/dev/null || true
    iptables -t nat -F TV_VPN_FIX 2>/dev/null || true

    # Отключение Mihomo
    if command -v mihomo-stop &> /dev/null; then
        mihomo-stop 2>/dev/null || true
    fi
    systemctl stop mihomo 2>/dev/null || true

    # Восстановление базового роутинга
    NET_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    [ -z "$NET_IFACE" ] && NET_IFACE="eth0"
    sysctl -w net.ipv4.ip_forward=1 > /dev/null
    iptables -t nat -A POSTROUTING -o $NET_IFACE -j MASQUERADE 2>/dev/null || true
    iptables -A FORWARD -j ACCEPT 2>/dev/null || true
    
    echo -e "${GREEN}  ✓ Модули отключены, интернет работает напрямую${NC}"

    echo -e "${YELLOW}[3/4] Полная очистка файлов и конфигов...${NC}"
    rm -rf /opt/zalp
    rm -rf /opt/mihomo /etc/mihomo
    rm -f /etc/systemd/system/nfqws.service
    rm -f /etc/systemd/system/mihomo.service
    rm -f /usr/local/bin/zalp /usr/local/bin/zalp-*
    rm -f /usr/local/bin/mihomo* /usr/local/bin/fix
    
    # Очистка cron
    crontab -l 2>/dev/null | grep -v "zalp-doctor" | grep -v "mihomo-watchdog" | grep -v "tv_fix_vpn" | crontab - || true
    
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true
    
    REMAINING=$(find_traces)
    if [ "$REMAINING" -gt 0 ]; then
        echo -e "${RED}  ⚠️  Осталось $REMAINING следов (требуется ручная проверка)${NC}"
    else
        echo -e "${GREEN}  ✓ Система полностью очищена${NC}"
    fi
else
    echo -e "${YELLOW}[2/4] Пропуск очистки${NC}"
    echo -e "${YELLOW}[3/4] Пропуск очистки${NC}"
fi

echo -e "${YELLOW}[4/4] Запуск установки Zalp v5.0...${NC}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT=""

if [ -x "$SCRIPT_DIR/install.sh" ]; then
    INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
elif [ -x "./install.sh" ]; then
    INSTALL_SCRIPT="./install.sh"
fi

if [ -z "$INSTALL_SCRIPT" ]; then
    echo -e "${RED}✗ Не удалось найти install.sh${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ Найден install.sh: $INSTALL_SCRIPT${NC}"
echo ""
exec "$INSTALL_SCRIPT"