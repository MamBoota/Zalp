#!/bin/bash

# ╔══════════════════════════════════════════════════════╗
# ║           Zalp Restore v4.0 (Hot Swap)               ║
# ║     Полная очистка + переустановка (без разрыва)     ║
# ╚══════════════════════════════════════════════════════╝

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Zalp Restore v4.0 (Hot Swap)               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Запускать только через sudo${NC}"
    exit 1
fi

# ── Функция поиска следов продукта ──
find_traces() {
    local traces=0
    [ -d /opt/zalp ] && ((traces++))
    [ -x /opt/zalp/binaries/my/nfqws ] 2>/dev/null && ((traces++))
    [ -f /etc/systemd/system/nfqws.service ] && ((traces++))
    [ -x /usr/local/bin/zalp-start ] && ((traces++))
    [ -x /usr/local/bin/zalp-stop ] && ((traces++))
    [ -x /usr/local/bin/zalp-restart ] && ((traces++))
    [ -x /usr/local/bin/zalp-status ] && ((traces++))
    [ -x /usr/local/bin/zalp-check ] && ((traces++))
    [ -x /usr/local/bin/zalp-doctor ] && ((traces++))
    [ -x /usr/local/bin/zalp-restore ] && ((traces++))
    [ -f /opt/zalp/domains.txt ] && ((traces++))
    [ -f /opt/zalp/domains-exclude.txt ] && ((traces++))
    [ -f /var/log/zalp-doctor.log ] && ((traces++))
    [ -f /var/log/zalp-install.log ] && ((traces++))
    systemctl is-active --quiet nfqws 2>/dev/null && ((traces++))
    crontab -l 2>/dev/null | grep -q "zalp-doctor" && ((traces++))
    iptables -t mangle -L 2>/dev/null | grep -q "NFQUEUE" && ((traces++))
    echo $traces
}

# ── 1. Проверка наличия следов ──
echo -e "${YELLOW}[1/4] Поиск следов установки Zalp...${NC}"
TRACES=$(find_traces)

if [ "$TRACES" -eq 0 ]; then
    echo -e "${YELLOW}  Следов установки не найдено.${NC}"
    echo -e "${YELLOW}  Запускаем чистую установку...${NC}"
    # Сразу переходим к поиску install.sh
    SKIP_CLEANUP=1
else
    echo -e "${GREEN}  ✓ Найдено $TRACES следов установки${NC}"
    SKIP_CLEANUP=0
fi

if [ "$SKIP_CLEANUP" -eq 0 ]; then
    # ── 2. Горячее отключение обхода (без разрыва интернета) ──
    echo -e "${YELLOW}[2/4] Горячее отключение обхода DPI...${NC}"
    
    # 2.1 Сначала убираем ТОЛЬКО правила NFQUEUE (обход DPI)
    # Это мгновенно отключает обход, но интернет продолжает работать
    echo -e "${CYAN}  → Отключение обхода DPI (NFQUEUE)...${NC}"
    iptables -t mangle -F PREROUTING 2>/dev/null || true
    iptables -t mangle -F OUTPUT 2>/dev/null || true
    ip6tables -t mangle -F PREROUTING 2>/dev/null || true
    ip6tables -t mangle -F OUTPUT 2>/dev/null || true
    
    # 2.2 Останавливаем сервис nfqws (он больше не нужен)
    echo -e "${CYAN}  → Остановка сервиса nfqws...${NC}"
    systemctl stop nfqws 2>/dev/null || true
    systemctl disable nfqws 2>/dev/null || true
    
    # 2.3 Убеждаемся, что базовый роутеринг работает (NAT + FORWARD)
    echo -e "${CYAN}  → Проверка базового роутеринга...${NC}"
    NET_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    [ -z "$NET_IFACE" ] && NET_IFACE="enp2s0"
    
    # IP forwarding должен быть включён
    if [ "$(sysctl -n net.ipv4.ip_forward)" != "1" ]; then
        sysctl -w net.ipv4.ip_forward=1 > /dev/null
    fi
    
    # NAT должен работать
    if ! iptables -t nat -L POSTROUTING -n | grep -q "MASQUERADE.*$NET_IFACE"; then
        iptables -t nat -A POSTROUTING -o $NET_IFACE -j MASQUERADE
    fi
    
    # FORWARD должен пропускать трафик
    if ! iptables -L FORWARD -n | grep -q "ACCEPT"; then
        iptables -A FORWARD -j ACCEPT
    fi
    
    echo -e "${GREEN}  ✓ Обход отключен, интернет работает напрямую${NC}"
    
    # ── 3. Полная очистка файлов и конфигов ──
    echo -e "${YELLOW}[3/4] Полная очистка файлов и конфигов...${NC}"
    
    # 3.1 Удаление каталога продукта
    echo -e "${CYAN}  → Удаление каталога /opt/zalp...${NC}"
    rm -rf /opt/zalp
    
    # 3.2 Удаление systemd-сервисов
    echo -e "${CYAN}  → Удаление systemd-сервисов...${NC}"
    rm -f /etc/systemd/system/nfqws.service
    rm -f /etc/systemd/system/3proxy.service
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true
    
    # 3.3 Удаление команд управления
    echo -e "${CYAN}  → Удаление команд zalp-*...${NC}"
    rm -f /usr/local/bin/zalp-start
    rm -f /usr/local/bin/zalp-stop
    rm -f /usr/local/bin/zalp-restart
    rm -f /usr/local/bin/zalp-status
    rm -f /usr/local/bin/zalp-check
    rm -f /usr/local/bin/zalp-doctor
    rm -f /usr/local/bin/zalp-restore
    
    # 3.4 Удаление cron-задачи
    echo -e "${CYAN}  → Удаление cron-задачи...${NC}"
    if crontab -l 2>/dev/null | grep -q "zalp-doctor"; then
        crontab -l 2>/dev/null | grep -v "zalp-doctor" | crontab -
    fi
    
    # 3.5 Удаление логов
    echo -e "${CYAN}  → Удаление логов...${NC}"
    rm -f /var/log/zalp-doctor.log
    rm -f /var/log/zalp-install.log
    
    # Проверка очистки
    REMAINING=$(find_traces)
    if [ "$REMAINING" -gt 0 ]; then
        echo -e "${RED}  ⚠️  Осталось $REMAINING следов${NC}"
    else
        echo -e "${GREEN}  ✓ Система полностью очищена (интернет работает)${NC}"
    fi
else
    echo -e "${YELLOW}[2/4] Пропуск очистки${NC}"
    echo -e "${YELLOW}[3/4] Пропуск очистки${NC}"
fi

# ── 4. Поиск и запуск install.sh ──
echo -e "${YELLOW}[4/4] Запуск установки Zalp...${NC}"

# Ищем install.sh: сначала рядом с собой, потом в текущей директории
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT=""

if [ -x "$SCRIPT_DIR/install.sh" ]; then
    INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
elif [ -f "$SCRIPT_DIR/install.sh" ]; then
    chmod +x "$SCRIPT_DIR/install.sh"
    INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
elif [ -x "./install.sh" ]; then
    INSTALL_SCRIPT="./install.sh"
elif [ -f "./install.sh" ]; then
    chmod +x "./install.sh"
    INSTALL_SCRIPT="./install.sh"
fi

if [ -z "$INSTALL_SCRIPT" ]; then
    echo -e "${RED}✗ Не удалось найти install.sh${NC}"
    echo -e "${YELLOW}  Убедитесь, что ${CYAN}install.sh${YELLOW} лежит в одной папке с ${CYAN}restore.sh${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ Найден install.sh: $INSTALL_SCRIPT${NC}"
echo ""
echo -e "${CYAN}  Запускаю установку (интернет продолжит работать)...${NC}"
echo ""

# Запускаем install.sh
exec "$INSTALL_SCRIPT"