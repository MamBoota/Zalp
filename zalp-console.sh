#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║        Zalp Unified Management Console v5.0          ║
# ╚══════════════════════════════════════════════════════╝

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'

# 1. Если запущено не от root, перезапускаем с sudo и СРАЗУ выходим из этой копии
[ "$EUID" -ne 0 ] && exec sudo "$0" "$@"

# 2. ГЛАВНОЕ ИСПРАВЛЕНИЕ: Если есть хотя бы один аргумент, выполняем его и СРАЗУ выходим.
# Меню НЕ открывается. Точка.
if [ $# -gt 0 ]; then
    case "$1" in
        start)   echo -e "${GREEN}▶ Запуск DPI...${NC}"; systemctl start nfqws; exit 0 ;;
        stop)    echo -e "${YELLOW}■ Остановка DPI...${NC}"; systemctl stop nfqws; exit 0 ;;
        restart) echo -e "${CYAN}⟳ Перезапуск DPI...${NC}"; systemctl restart nfqws; exit 0 ;;
        status)  systemctl status nfqws --no-pager; exit 0 ;;
        doctor|check)
            echo -e "${CYAN}🩺 Диагностика и лечение (перезапуск nfqws + iptables)...${NC}"
            systemctl restart nfqws
            echo -e "${GREEN}✅ Готово. Правила восстановлены.${NC}"
            exit 0 ;;
        test)    cd /opt/zalp && [ -f blockcheck.sh ] && sudo ./blockcheck.sh || echo -e "${RED}✗ Не найден${NC}"; exit 0 ;;
        restore) [ -f /opt/zalp/restore.sh ] && sudo /opt/zalp/restore.sh || echo -e "${RED}✗ Не найден${NC}"; exit 0 ;;
        mihomo)  [ -x /usr/local/bin/mihomo-start ] && /usr/local/bin/mihomo-start || echo -e "${YELLOW}⚠ Не установлен${NC}"; exit 0 ;;
        tvfix)   command -v fix >/dev/null 2>&1 && fix start || echo -e "${YELLOW}⚠ Не установлен${NC}"; exit 0 ;;
        *)       echo -e "${RED}⚠ Неизвестная команда: $1${NC}"; exit 1 ;;
    esac
fi

# 3. Если аргументов НЕТ (введено просто "sudo zalp"), только тогда открываем меню.
VER_FILE="/opt/zalp/VERSION"
CURRENT_VERSION=$(cat "$VER_FILE" 2>/dev/null || echo "0.0")

show_banner() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Zalp Unified Console v5.0                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo -e "  Версия продукта: ${CYAN}v$CURRENT_VERSION${NC}"
    local dpi="🔴" nfq="🔴" doc="🔴" mih="⚪" tvf="⚪"
    iptables -t mangle -L 2>/dev/null | grep -q "NFQUEUE" && dpi="🟢"
    systemctl is-active --quiet nfqws && nfq="🟢"
    (systemctl is-active --quiet zalp-doctor.timer 2>/dev/null || grep -q "zalp-doctor" /var/spool/cron/crontabs/root 2>/dev/null) && doc="🟢"
    [ -x /usr/local/bin/mihomo-start ] && mih="🟢"
    iptables -t mangle -L 2>/dev/null | grep -q "TV_VPN_FIX" && tvf="🟢"
    echo -e "  DPI Bypass: $dpi   NFQWS: $nfq   Doctor: $doc"
    echo -e "  Mihomo: $mih   TV Fix: $tvf"
    echo -e "${GREEN}────────────────────────────────────────────────────────${NC}"
}

pause() { read -rp "  [Enter] — вернуться в меню..."; }

while true; do
    show_banner
    echo "  1) Статус системы"
    echo "  2) Полная диагностика (Doctor)"
    echo "  3) Запустить обход DPI"
    echo "  4) Остановить обход DPI"
    echo "  5) Безопасный перезапуск"
    echo "  6) Doctor: ручное лечение"
    echo "  7) Логи Doctor"
    echo "  8) Управление Mihomo (прокси)"
    echo "  9) Управление TV Fix (VPN для ТВ)"
    echo " 10) Тестирование стратегий (Blockcheck)"
    echo " 11) Проверить обновления"
    echo " 12) Установить обновление"
    echo "  0) Выход"
    echo " "
    read -rp "  Выбор: " choice
    choice=$(echo "$choice" | tr -d '\r')
    
    case "$choice" in
        1) systemctl status nfqws --no-pager; pause ;;
        2|6) echo -e "${CYAN}🩺 Запуск лечения...${NC}"; systemctl restart nfqws; echo -e "${GREEN}✅ Готово${NC}"; pause ;;
        3) echo -e "${GREEN}▶ Запуск DPI...${NC}"; systemctl start nfqws; pause ;;
        4) echo -e "${YELLOW}■ Остановка DPI...${NC}"; systemctl stop nfqws; pause ;;
        5) echo -e "${CYAN}⟳ Перезапуск DPI...${NC}"; systemctl restart nfqws; pause ;;
        7) tail -30 /var/log/zalp-doctor.log 2>/dev/null || echo "  Лог пуст"; pause ;;
        8) 
            if [ -x /usr/local/bin/mihomo-start ]; then
                echo "  1) Запустить"
                echo "  2) Остановить"
                echo "  3) Перезапустить"
                echo "  4) Диагностика"
                read -rp "  Выбор [1/2/3/4]: " m_choice; m_choice=$(echo "$m_choice" | tr -d '\r')
                case "$m_choice" in 1) mihomo-start;; 2) mihomo-stop;; 3) mihomo-restart;; 4) mihomo-test;; *) echo "  Неверный выбор.";; esac
            else echo -e "${YELLOW}  Mihomo не установлен.${NC}"; fi
            pause ;;
        9)
            if iptables -t mangle -L 2>/dev/null | grep -q "TV_VPN_FIX"; then
                echo "  1) Запустить"
                echo "  2) Остановить"
                echo "  3) Перезапустить"
                echo "  4) Диагностика"
                read -rp "  Выбор [1/2/3/4]: " m_choice; m_choice=$(echo "$m_choice" | tr -d '\r')
                case "$t_choice" in 1) fix start;; 2) fix stop;; 3) fix restart;; 4) fix test;; *) echo "  Неверный выбор.";; esac
            else echo -e "${YELLOW}  TV Fix не установлен.${NC}"; fi
            pause ;;
        10) echo -e "${CYAN}  Запуск blockcheck.sh...${NC}"; [ -f /opt/zalp/blockcheck.sh ] && cd /opt/zalp && sudo ./blockcheck.sh || echo -e "${RED}  ✗ Не найден${NC}"; pause ;;
        11) echo -e "${GREEN}  Проверка обновлений (функционал в разработке)...${NC}"; pause ;;
        12) echo -e "${YELLOW}  Используйте скрипт restore.sh из папки проекта для обновления.${NC}"; pause ;;
        0) echo -e "${GREEN}  Выход из панели управления. До свидания!${NC}"; exit 0 ;;
        *) echo -e "${RED}  Неверный выбор.${NC}"; pause ;;
    esac
done
