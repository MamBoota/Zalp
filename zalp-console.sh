#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║        Zalp Unified Management Console v5.0          ║
# ╚══════════════════════════════════════════════════════╝

ZALP_REPO="MamBoota/Zalp"
VER_FILE="/opt/zalp/VERSION"
CACHE_FILE="/opt/zalp/.update_cache"
CACHE_VER="/opt/zalp/.update_ver"
CACHE_TTL=86400

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

[ "$EUID" -ne 0 ] && exec sudo "$0" "$@"

CURRENT_VERSION=$(cat "$VER_FILE" 2>/dev/null || echo "0.0")
UPDATE_AVAILABLE=0
REMOTE_TAG=""

pause() { read -rp "  [Enter] — вернуться в меню..."; }

norm_ver() { echo "$1" | sed 's/^v//'; }
is_newer() {
    [ "$1" = "$2" ] && return 1
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$2" ]
}

get_remote_tag() {
    local v
    v=$(curl -s -m 10 "https://api.github.com/repos/$ZALP_REPO/releases/latest" 2>/dev/null | grep -m1 '"tag_name"' | sed 's/.*"tag_name": "\([^"]*\)".*/\1/')
    if [ -z "$v" ]; then
        v=$(curl -s -m 10 "https://api.github.com/repos/$ZALP_REPO/tags" 2>/dev/null | grep -m1 '"name"' | sed 's/.*"name": "\([^"]*\)".*/\1/')
    fi
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
    if [ -n "$REMOTE_TAG" ] && is_newer "$(norm_ver "$CURRENT_VERSION")" "$(norm_ver "$REMOTE_TAG")"; then
        UPDATE_AVAILABLE=1
    else
        UPDATE_AVAILABLE=0
    fi
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
    if [ $ok -ne 1 ]; then
        echo -e "${RED}  ✗ Ошибка загрузки. Обновление отменено.${NC}"
        rm -rf "$dir"
        return 1
    fi
    echo -e "${GREEN}  ✓ Файлы загружены. Запускаю горячую замену...${NC}"
    "$dir/restore.sh"
    local rc=$?
    rm -rf "$dir"
    return $rc
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
    
    if [ "$UPDATE_AVAILABLE" = "1" ]; then
        echo -e "  ${YELLOW}⚠️  ДОСТУПНО ОБНОВЛЕНИЕ: v$(norm_ver "$REMOTE_TAG") (у вас v$CURRENT_VERSION)${NC}"
    fi
    echo -e "${GREEN}────────────────────────────────────────────────────────${NC}"
}

check_update

while true; do
    show_banner
    echo "  1) Статус системы (zalp status)"
    echo "  2) Полная диагностика (zalp check)"
    echo "  3) Запустить обход DPI (zalp start)"
    echo "  4) Остановить обход DPI (zalp stop)"
    echo "  5) Безопасный перезапуск (zalp restart)"
    echo "  6) Doctor: ручное лечение (zalp doctor)"
    echo "  7) Логи Doctor"
    echo "  8) Управление Mihomo (прокси)"
    echo "  9) Управление TV Fix (VPN для ТВ)"
    echo " 10) Тестирование стратегий (Blockcheck)"
    echo " 11) Проверить обновления"
    echo " 12) Установить обновление"
    echo "  0) Выход"
    echo " "
    read -rp "  Выбор: " choice
    
    case "$choice" in
        1) zalp status; pause ;;
        2) zalp check; pause ;;
        3) zalp start; pause ;;
        4) zalp stop; pause ;;
        5) zalp restart; pause ;;
        6) zalp doctor; pause ;;
        7) tail -30 /var/log/zalp-doctor.log 2>/dev/null || echo "  Лог пуст"; pause ;;
        8) 
            if [ -x /usr/local/bin/mihomo-start ]; then
                echo "  Выберите действие для Mihomo:"
                echo "  a) Запустить (mihomo-start)"
                echo "  b) Остановить (mihomo-stop)"
                echo "  c) Перезапустить (mihomo-restart)"
                echo "  d) Диагностика (mihomo-test)"
                read -rp "  Выбор [a/b/c/d]: " m_choice
                case "$m_choice" in
                    a) mihomo-start ;;
                    b) mihomo-stop ;;
                    c) mihomo-restart ;;
                    d) mihomo-test ;;
                    *) echo "  Неверный выбор." ;;
                esac
            else
                echo -e "${YELLOW}  Mihomo не установлен. Запустите install.sh для добавления модуля.${NC}"
            fi
            pause ;;
        9)
            if iptables -t mangle -L 2>/dev/null | grep -q "TV_VPN_FIX"; then
                echo "  Выберите действие для TV Fix:"
                echo "  a) Запустить (fix start)"
                echo "  b) Остановить (fix stop)"
                echo "  c) Перезапустить (fix restart)"
                echo "  d) Диагностика (fix test)"
                read -rp "  Выбор [a/b/c/d]: " t_choice
                case "$t_choice" in
                    a) fix start ;;
                    b) fix stop ;;
                    c) fix restart ;;
                    d) fix test ;;
                    *) echo "  Неверный выбор." ;;
                esac
            else
                echo -e "${YELLOW}  TV Fix не установлен. Запустите install.sh для добавления модуля.${NC}"
            fi
            pause ;;
        10)
            echo -e "${CYAN}  Запуск blockcheck.sh для подбора стратегии...${NC}"
            echo "  Следуйте инструкциям на экране."
            if [ -f /opt/zalp/blockcheck.sh ]; then
                cd /opt/zalp && sudo ./blockcheck.sh
            else
                echo -e "${RED}  ✗ Скрипт blockcheck.sh не найден в /opt/zalp/${NC}"
            fi
            pause ;;
        11) 
            echo "  Проверка обновлений..."
            check_update
            if [ "$UPDATE_AVAILABLE" = "1" ]; then
                echo -e "  ${YELLOW}Доступна версия: v$(norm_ver "$REMOTE_TAG")${NC}"
            else
                echo -e "  ${GREEN}У вас последняя версия (v$CURRENT_VERSION)${NC}"
            fi
            pause ;;
        12) 
            if [ "$UPDATE_AVAILABLE" = "1" ]; then
                read -rp "  Установить v$(norm_ver "$REMOTE_TAG")? [y/N]: " ans
                case "$ans" in
                    y|Y|д|Д) 
                        if do_update; then
                            echo -e "${GREEN}  ✓ Обновление завершено!${NC}"
                            echo "  Консоль перезапустится при следующем запуске."
                            read -rp "  [Enter] — выход..."
                            exit 0
                        fi ;;
                    *) echo "  Отменено." ;;
                esac
            else
                echo "  Обновлений нет."
            fi
            pause ;;
        0) exit 0 ;;
        *) echo "  Неверный выбор."; pause ;;
    esac
done