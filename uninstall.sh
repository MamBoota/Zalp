#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║           Zalp Uninstaller v1.0                      ║
# ║     Полное удаление продукта без разрыва интернета   ║
# ╚══════════════════════════════════════════════════════╝
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Zalp Uninstaller v1.0                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Запускать только через sudo${NC}"
    exit 1
fi

# ── Проверка: а что вообще установлено? ──
echo -e "${YELLOW}[1/7] Анализ установленных компонентов...${NC}"
TRACES=0
[ -d /opt/zalp ] && ((TRACES++))
[ -f /etc/systemd/system/nfqws.service ] && ((TRACES++))
[ -x /usr/local/bin/zalp-start ] && ((TRACES++))
[ -x /usr/local/bin/zalp ] && ((TRACES++))
[ -f /var/log/zalp-doctor.log ] && ((TRACES++))
crontab -l 2>/dev/null | grep -q "zalp-doctor" && ((TRACES++))
iptables -t mangle -L 2>/dev/null | grep -q "NFQUEUE" && ((TRACES++))

if [ "$TRACES" -eq 0 ]; then
    echo -e "${YELLOW}  ℹ️  Следов установки Zalp не найдено. Система чистая.${NC}"
    exit 0
fi
echo -e "${GREEN}  ✓ Найдено $TRACES следов установки${NC}"

# ── 2. Остановка сервисов (без разрыва интернета) ──
echo -e "${YELLOW}[2/7] Остановка сервисов Zalp...${NC}"

# 2.1 Полное удаление всех следов Zalp и TV Fix из iptables
echo -e "${CYAN}  → Удаление правил Zalp и TV Fix (без затрагивания сторонних сервисов)...${NC}"

# 1. Удаляем ВСЕ прыжки в цепочки Zalp из PREROUTING (и mangle, и nat)
for table in mangle nat; do
    while iptables -t $table -D PREROUTING -j ZALP_DPI 2>/dev/null; do :; done
    while ip6tables -t $table -D PREROUTING -j ZALP_DPI 2>/dev/null; do :; done
    while iptables -t $table -D PREROUTING -j TV_VPN_FIX 2>/dev/null; do :; done
    while ip6tables -t $table -D PREROUTING -j TV_VPN_FIX 2>/dev/null; do :; done
done

# 2. Агрессивно очищаем и удаляем сами цепочки Zalp и TV Fix
for chain in ZALP_DPI TV_VPN_FIX; do
    # Очистка содержимого
    iptables -t mangle -F $chain 2>/dev/null || true
    ip6tables -t mangle -F $chain 2>/dev/null || true
    iptables -t nat -F $chain 2>/dev/null || true
    ip6tables -t nat -F $chain 2>/dev/null || true
    
    # Удаление самих цепочек
    iptables -t mangle -X $chain 2>/dev/null || true
    ip6tables -t mangle -X $chain 2>/dev/null || true
    iptables -t nat -X $chain 2>/dev/null || true
    ip6tables -t nat -X $chain 2>/dev/null || true
done

# 3. Останавливаем сервисы
echo -e "${CYAN}  → Остановка сервиса nfqws...${NC}"
systemctl stop nfqws 2>/dev/null || true
systemctl disable nfqws 2>/dev/null || true

echo -e "${GREEN}  ✓ Сервисы остановлены, интернет работает напрямую${NC}"

# ── 3. Удаление cron-задачи ──
echo -e "${YELLOW}[3/7] Удаление cron-задачи Doctor...${NC}"
if crontab -l 2>/dev/null | grep -q "zalp-doctor"; then
    crontab -l 2>/dev/null | grep -v "zalp-doctor" | crontab -
    echo -e "${GREEN}  ✓ Cron-задача удалена${NC}"
else
    echo -e "${CYAN}  — Cron-задача не найдена${NC}"
fi

# ── 4. Удаление systemd-сервисов ──
echo -e "${YELLOW}[4/7] Удаление systemd-сервисов...${NC}"
if [ -f /etc/systemd/system/nfqws.service ]; then
    rm -f /etc/systemd/system/nfqws.service
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true
    echo -e "${GREEN}  ✓ Сервис nfqws удалён${NC}"
else
    echo -e "${CYAN}  — Сервис nfqws не найден${NC}"
fi

# ── 5. Удаление команд управления ──
echo -e "${YELLOW}[5/7] Удаление команд управления zalp-*...${NC}"
COMMANDS_REMOVED=0
for cmd in zalp zalp-start zalp-stop zalp-restart zalp-status zalp-check zalp-doctor zalp-restore; do
    if [ -f /usr/local/bin/$cmd ]; then
        rm -f /usr/local/bin/$cmd
        ((COMMANDS_REMOVED++))
    fi
done
echo -e "${GREEN}  ✓ Удалено команд: $COMMANDS_REMOVED${NC}"

# ── 6. Удаление каталога продукта и конфигов ──
echo -e "${YELLOW}[6/7] Удаление каталога /opt/zalp...${NC}"
if [ -d /opt/zalp ]; then
    rm -rf /opt/zalp
    echo -e "${GREEN}  ✓ Каталог /opt/zalp удалён${NC}"
else
    echo -e "${CYAN}  — Каталог не найден${NC}"
fi

# Удаление логов
echo -e "${CYAN}  → Удаление логов...${NC}"
LOGS_REMOVED=0
for log in /var/log/zalp-doctor.log /var/log/zalp-install.log; do
    if [ -f "$log" ]; then
        rm -f "$log"
        ((LOGS_REMOVED++))
    fi
done
echo -e "${GREEN}  ✓ Удалено логов: $LOGS_REMOVED${NC}"

# ── 7. Финальная проверка ──
echo -e "${YELLOW}[7/7] Финальная проверка чистоты...${NC}"
REMAINING=0
[ -d /opt/zalp ] && ((REMAINING++))
[ -f /etc/systemd/system/nfqws.service ] && ((REMAINING++))
[ -x /usr/local/bin/zalp-start ] && ((REMAINING++))
[ -x /usr/local/bin/zalp ] && ((REMAINING++))
crontab -l 2>/dev/null | grep -q "zalp-doctor" && ((REMAINING++))
iptables -t mangle -L 2>/dev/null | grep -q "NFQUEUE" && ((REMAINING++))

if [ "$REMAINING" -gt 0 ]; then
    echo -e "${RED}  ⚠️  Осталось $REMAINING следов (возможно, требуются ручная проверка)${NC}"
else
    echo -e "${GREEN}  ✓ Система полностью очищена${NC}"
fi

# ── Итог ──
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Zalp полностью удалён из системы                 ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║  Что было удалено:                                   ║${NC}"
echo -e "${CYAN}║    • Каталог /opt/zalp (движок + конфиги)            ║${NC}"
echo -e "${CYAN}║    • Systemd-сервис nfqws                            ║${NC}"
echo -e "${CYAN}║    • Cron-задача Doctor                              ║${NC}"
echo -e "${CYAN}║    • Команды управления zalp-*                       ║${NC}"
echo -e "${CYAN}║    • Логи /var/log/zalp-*.log                        ║${NC}"
echo -e "${CYAN}║    • Правила NFQUEUE в iptables/ip6tables            ║${NC}"
echo -e "${CYAN}║    • Цепочки ZALP_DPI и TV_VPN_FIX                   ║${NC}"
echo -e "${CYAN}║                                                      ║${NC}"
echo -e "${CYAN}║  Что НЕ было изменено (осталось как было):           ║${NC}"
echo -e "${CYAN}║    • IP forwarding в /etc/sysctl.conf                ║${NC}"
echo -e "${CYAN}║    • Базовый NAT и FORWARD (роутинг работает)        ║${NC}"
echo -e "${CYAN}║    • Сетевые интерфейсы                              ║${NC}"
echo -e "${CYAN}║    • Сторонние правила iptables (Docker и др.)       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}💡 Для полной переустановки выполни: ${CYAN}sudo ./install.sh${NC}"