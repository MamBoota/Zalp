#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║        Zalp Unified Management Console v5.0          ║
# ╚══════════════════════════════════════════════════════╝

ZALP_REPO="MamBoota/Zalp"
VER_FILE="/opt/zalp/VERSION"
CACHE_FILE="/opt/zalp/.update_cache"
CACHE_VER="/opt/zalp/.update_ver"
CACHE_TTL=86400

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'

[ "$EUID" -ne 0 ] && exec sudo "$0" "$@"

CURRENT_VERSION=$(cat "$VER_FILE" 2>/dev/null || echo "0.0")
UPDATE_AVAILABLE=0; REMOTE_TAG=""

pause() { read -rp "  [Enter] — вернуться в меню..."; }
norm_ver() { echo "$1" | sed 's/^v//'; }
is_newer() { [ "$1" = "$2" ] && return 1; [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$2" ]; }

get_remote_tag() {
    local v
    v=$(curl -s -m 10 "https://api.github.com/repos/$ZALP_REPO/releases/latest" 2>/dev/null | grep -m1 '"tag_name"' | sed 's/.*"tag_name": "\([^"]*\)".*/\1/')
    [ -z "$v" ] && v=$(curl -s -m 10 "https://api.github.com/repos/$ZALP_REPO/tags" 2>/dev/null | grep -m1 '"name"' | sed 's/.*"name": "\([^"]*\)".*/\1/')
    echo "$v"
}

check_update() {
    local now=$(date +%s)
    local last=$(cat "$CACHE_FILE" 2>/dev/null || echo 0)
    if [ $((now - last)) -lt $CACHE_TTL ] && [ -f "$CACHE_VER" ]; then
        REMOTE_TAG=$(cat "$CACHE_VER")
    else
        REMOTE_TAG=$(get_remote_tag)
        echo "$now" > "$CACHE_FILE" 2>/dev/null
        echo "$REMOTE_TAG" > "$CACHE_VER" 2>/dev/null
    fi
    [ -n "$REMOTE_TAG" ] && is_newer "$(norm_ver "$CURRENT_VERSION")" "$(norm_ver "$REMOTE_TAG")" && UPDATE_AVAILABLE=1 || UPDATE_AVAILABLE=0
}

do_update() {
    local dir="/tmp/zalp-update-$$"
    echo -e "${YELLOW}  Скачивание версии $REMOTE_TAG...${NC}"
    mkdir -p "$dir"
    local f ok=1
    for f in install.sh restore.sh zalp-console.sh; do
        curl -sL -m 60 "https://raw.githubusercontent.com/$ZALP_REPO/$REMOTE_TAG/$f" -o "$dir/$f" || ok=0
        head -1 "$dir/$f" 2>/dev/null | grep -q "#!/bin/bash" || ok=0
        chmod +x "$dir/$f" 2>/dev/null
    done
    if [ $ok -ne 1 ]; then echo -e "${RED}  ✗ Ошибка загрузки. Обновление отменено.${NC}"; rm -rf "$dir"; return 1; fi
    echo -e "${GREEN}  ✓ Файлы загружены. Запускаю горячую замену...${NC}"
    "$dir/restore.sh"
    local rc=$?; rm -rf "$dir"; return $rc
}

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
    [ "$UPDATE_AVAILABLE" = "1" ] && echo -e "  ${YELLOW}⚠️  ДОСТУПНО ОБНОВЛЕНИЕ: v$(norm_ver "$REMOTE_TAG") (у вас v$CURRENT_VERSION)${NC}"
    echo -e "${GREEN}────────────────────────────────────────────────────────${NC}"
}

check_update

# ==============================================================================
# 1. ОБРАБОТКА АРГУМЕНТОВ (БЕЗ РЕКУРСИИ!)
# ==============================================================================
if [ -n "$1" ]; then
    case "$1" in
        start) echo -e "${GREEN}▶ Запуск DPI...${NC}"; systemctl start nfqws; exit 0 ;;
        stop) echo -e "${YELLOW}■ Остановка DPI...${NC}"; systemctl stop nfqws; exit 0 ;;
        restart) echo -e "${CYAN}⟳ Перезапуск DPI...${NC}"; systemctl restart nfqws; exit 0 ;;
        status) systemctl status nfqws --no-pager; exit 0 ;;
        check|doctor)
            echo -e "${CYAN}🩺 Запуск диагностики и лечения (Doctor)...${NC}"
            # ВАЖНО: Выполняем действие напрямую, а не вызываем "zalp doctor" снова!
            systemctl restart nfqws
            echo -e "${GREEN}✅ Сервис nfqws перезапущен. Правила iptables восстановлены.${NC}"
            exit 0 ;;
        test) cd /opt/zalp && [ -f blockcheck.sh ] && sudo ./blockcheck.sh || echo -e "${RED}✗ blockcheck.sh не найден${NC}"; exit 0 ;;
        restore) [ -f /opt/zalp/restore.sh ] && sudo /opt/zalp/restore.sh || echo -e "${RED}✗ restore.sh не найден${NC}"; exit 0 ;;
        mihomo) [ -x /usr/local/bin/mihomo-start ] && /usr/local/bin/mihomo-start || echo -e "${YELLOW}⚠ Mihomo не установлен${NC}"; exit 0 ;;
        tvfix) command -v fix >/dev/null 2>&1 && fix start || echo -e "${YELLOW}⚠ TV Fix не установлен${NC}"; exit 0 ;;
        *) echo -e "${RED}⚠ Неизвестная команда: $1${NC}"; exit 1 ;;
    esac
fi

# ==============================================================================
# 2. ИНТЕРАКТИВНОЕ МЕНЮ
# ==============================================================================
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
    choice=$(echo "$choice" | tr -d '\r') # Защита от CRLF
    
    case "$choice" in
        1) systemctl status nfqws --no-pager; pause ;;
        2|6) echo -e "${CYAN}🩺 Запуск лечения...${NC}"; systemctl restart nfqws; echo -e "${GREEN}✅ Готово${NC}"; pause ;;
        3) echo -e "${GREEN}▶ Запуск DPI...${NC}"; systemctl start nfqws; pause ;;
        4) echo -e "${YELLOW}■ Остановка DPI...${NC}"; systemctl stop nfqws; pause ;;
        5) echo -e "${CYAN}⟳ Перезапуск DPI...${NC}"; systemctl restart nfqws; pause ;;
        7) tail -30 /var/log/zalp-doctor.log 2>/dev/null || echo "  Лог пуст"; pause ;;
        8) 
            if [ -x /usr/local/bin/mihomo-start ]; then
                echo "  a) Запустить  b) Остановить  c) Перезапустить  d) Диагностика"
                read -rp "  Выбор [a/b/c/d]: " m_choice; m_choice=$(echo "$m_choice" | tr -d '\r')
                case "$m_choice" in a) mihomo-start;; b) mihomo-stop;; c) mihomo-restart;; d) mihomo-test;; *) echo "  Неверный выбор.";; esac
            else echo -e "${YELLOW}  Mihomo не установлен.${NC}"; fi
            pause ;;
        9)
            if iptables -t mangle -L 2>/dev/null | grep -q "TV_VPN_FIX"; then
                echo "  a) Запустить  b) Остановить  c) Перезапустить  d) Диагностика"
                read -rp "  Выбор [a/b/c/d]: " t_choice; t_choice=$(echo "$t_choice" | tr -d '\r')
                case "$t_choice" in a) fix start;; b) fix stop;; c) fix restart;; d) fix test;; *) echo "  Неверный выбор.";; esac
            else echo -e "${YELLOW}  TV Fix не установлен.${NC}"; fi
            pause ;;
        10) echo -e "${CYAN}  Запуск blockcheck.sh...${NC}"; [ -f /opt/zalp/blockcheck.sh ] && cd /opt/zalp && ./blockcheck.sh || echo -e "${RED}  ✗ Не найден${NC}"; pause ;;
        11) check_update; [ "$UPDATE_AVAILABLE" = "1" ] && echo -e "  ${YELLOW}Доступна: v$(norm_ver "$REMOTE_TAG")${NC}" || echo -e "  ${GREEN}Последняя версия${NC}"; pause ;;
        12) 
            if [ "$UPDATE_AVAILABLE" = "1" ]; then
                read -rp "  Установить v$(norm_ver "$REMOTE_TAG")? [y/N]: " ans; ans=$(echo "$ans" | tr -d '\r')
                case "$ans" in y|Y|д|Д) do_update && echo -e "${GREEN}  ✓ Готово!${NC}" && read -rp "  [Enter] — выход..." && exit 0 ;; *) echo "  Отменено." ;; esac
            else echo "  Обновлений нет."; fi
            pause ;;
        0) echo -e "${GREEN}  Выход. До свидания!${NC}"; exit 0 ;;
        *) echo -e "${RED}  Неверный выбор.${NC}"; pause ;;
    esac
done
