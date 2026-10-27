#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║           Zalp Restore v5.2 (Hot Swap)               ║
# ║     Полная очистка + переустановка (без разрыва)     ║
# ╚══════════════════════════════════════════════════════╝
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Определяем SCRIPT_DIR сразу, чтобы он был доступен везде
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Zalp Restore v5.2 (Hot Swap)               ║${NC}"
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
    iptables -t mangle -L 2>/dev/null | grep -q "ZALP_DPI" && ((traces++))
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
    
    iptables -t mangle -D PREROUTING -j ZALP_DPI 2>/dev/null || true
    ip6tables -t mangle -D PREROUTING -j ZALP_DPI 2>/dev/null || true
    iptables -t mangle -F ZALP_DPI 2>/dev/null || true
    ip6tables -t mangle -F ZALP_DPI 2>/dev/null || true
    iptables -t mangle -X ZALP_DPI 2>/dev/null || true
    ip6tables -t mangle -X ZALP_DPI 2>/dev/null || true
    systemctl stop nfqws 2>/dev/null || true

    if command -v fix &> /dev/null; then fix stop 2>/dev/null || true; fi
    iptables -t mangle -F TV_VPN_FIX 2>/dev/null || true
    iptables -t nat -F TV_VPN_FIX 2>/dev/null || true

    if command -v mihomo-stop &> /dev/null; then mihomo-stop 2>/dev/null || true; fi
    systemctl stop mihomo 2>/dev/null || true

    NET_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    [ -z "$NET_IFACE" ] && NET_IFACE="eth0"
    sysctl -w net.ipv4.ip_forward=1 > /dev/null
    iptables -t nat -A POSTROUTING -o $NET_IFACE -j MASQUERADE 2>/dev/null || true
    iptables -A FORWARD -j ACCEPT 2>/dev/null || true
    
    echo -e "${GREEN}  ✓ Модули отключены, интернет работает напрямую${NC}"

    echo -e "${YELLOW}[3/4] Полная очистка файлов и конфигов Zalp...${NC}"
    echo -e "${YELLOW}  💾 Сохранение конфигурации TV MACs...${NC}"
    # Сохраняем ПЕРЕД удалением
    cp -f /opt/zalp/tv_macs.conf /tmp/tv_macs.conf.bak 2>/dev/null || true
    
    rm -rf /opt/zalp
    rm -f /etc/systemd/system/nfqws.service
    rm -f /usr/local/bin/zalp /usr/local/bin/zalp-*
    
    crontab -l 2>/dev/null | grep -v "zalp-doctor" | crontab - || true
    
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true
    
    echo -e "${GREEN}  ✓ Система полностью очищена от Zalp${NC}"
else
    echo -e "${YELLOW}[2/4] Пропуск очистки${NC}"
    echo -e "${YELLOW}[3/4] Пропуск очистки${NC}"
fi

echo -e "${YELLOW}[4/4] Запуск установки Zalp v5.2...${NC}"
INSTALL_SCRIPT=""

if [ -x "$SCRIPT_DIR/install.sh" ]; then
    INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
elif [ -x "./install.sh" ]; then
    INSTALL_SCRIPT="./install.sh"
fi

if [ -z "$INSTALL_SCRIPT" ]; then
    echo -e "${RED}✗ Скрипт /install.sh не найден. Убедитесь, что файл существует или произведите установку в ручную.${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ Скрипт install.sh успешно найден: $INSTALL_SCRIPT${NC}"
echo -e "${GREEN}  ✓ Переустановка завершена успешно.${NC}"

# ВАЖНО: используем bash, а не exec, чтобы скрипт продолжил работу после установки
bash "$INSTALL_SCRIPT"

# 🔄 ВОССТАНОВЛЕНИЕ КОНФИГА ПОСЛЕ УСПЕШНОЙ УСТАНОВКИ
# СТАЛО (умное восстановление):
if [ -f /tmp/tv_macs.conf.bak ]; then
    # Проверяем, есть ли в бэкапе хоть один MAC-адрес (ищем символ ":")
    if grep -q ":" /tmp/tv_macs.conf.bak; then
        echo -e "${YELLOW}  🔄 Восстановление пользовательских TV MACs из резервной копии...${NC}"
        cp -f /tmp/tv_macs.conf.bak /opt/zalp/tv_macs.conf
        if command -v fix &> /dev/null; then
            fix restart
        fi
        echo -e "${GREEN}  ✓ Конфигурация TV MACs успешно восстановлена!${NC}"
    else
        echo -e "${CYAN}  ℹ️  Резервная копия TV MACs пуста, используем актуальный файл из репозитория.${NC}"
    fi
    rm -f /tmp/tv_macs.conf.bak
fi