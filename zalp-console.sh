#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║        Zalp Unified Management Console v5.2          ║
# ║     С исправленной логикой iptables (Anti-Mihomo)    ║
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

# --- НОВАЯ ФУНКЦИЯ: Безопасное применение правил ---
# --- ИСПРАВЛЕННАЯ ФУНКЦИЯ: Абсолютно надежное применение правил ---
apply_zalp_rules() {
    echo -e "${CYAN}  Применение правил iptables (защита от перезаписи и дубликатов)...${NC}"
    
    # 1. Создаем изолированную цепочку, если её нет
    iptables -t mangle -N ZALP_DPI 2>/dev/null || true
    ip6tables -t mangle -N ZALP_DPI 2>/dev/null || true

    # 2. Очищаем ТОЛЬКО нашу цепочку (гарантированно убирает любые мусорные правила внутри неё)
    iptables -t mangle -F ZALP_DPI
    ip6tables -t mangle -F ZALP_DPI

    # 3. Наполняем нашу цепочку правилами (ОТДЕЛЬНЫЕ строки для 100% совместимости)
    iptables -t mangle -A ZALP_DPI -p tcp --dport 80 -j NFQUEUE --queue-num 1
    iptables -t mangle -A ZALP_DPI -p tcp --dport 443 -j NFQUEUE --queue-num 1
    iptables -t mangle -A ZALP_DPI -p udp --dport 443 -j NFQUEUE --queue-num 1
    
    ip6tables -t mangle -A ZALP_DPI -p tcp --dport 80 -j NFQUEUE --queue-num 1
    ip6tables -t mangle -A ZALP_DPI -p tcp --dport 443 -j NFQUEUE --queue-num 1
    ip6tables -t mangle -A ZALP_DPI -p udp --dport 443 -j NFQUEUE --queue-num 1

    # 4. ГАРАНТИРОВАННО удаляем ВСЕ упоминания прыжка в ZALP_DPI из PREROUTING
    while iptables -t mangle -D PREROUTING -j ZALP_DPI 2>/dev/null; do :; done
    while ip6tables -t mangle -D PREROUTING -j ZALP_DPI 2>/dev/null; do :; done

    # 5. Вставляем прыжок СТРОГО на вторую позицию (оставляя первую для TV_VPN_FIX, если он есть)
    iptables -t mangle -I PREROUTING 2 -j ZALP_DPI
    ip6tables -t mangle -I PREROUTING 2 -j ZALP_DPI
    
    echo -e "${GREEN}  ✓ Правила iptables корректно установлены (Zalp на позиции 2, изоляция сохранена)${NC}"
}

remove_zalp_rules() {
    # Гарантированное удаление всех прыжков
    while iptables -t mangle -D PREROUTING -j ZALP_DPI 2>/dev/null; do :; done
    while ip6tables -t mangle -D PREROUTING -j ZALP_DPI 2>/dev/null; do :; done
    
    # Очистка и удаление самой цепочки
    iptables -t mangle -F ZALP_DPI 2>/dev/null || true
    ip6tables -t mangle -F ZALP_DPI 2>/dev/null || true
    iptables -t mangle -X ZALP_DPI 2>/dev/null || true
    ip6tables -t mangle -X ZALP_DPI 2>/dev/null || true
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
    echo -e "${GREEN}║         Zalp Unified Console v5.2 (Fixed IPT)        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo -e "  Версия продукта: ${CYAN}v$CURRENT_VERSION${NC}"
    
    local dpi="🔴" nfq="🔴" doc="🔴" mih="⚪" tvf="⚪"
    
    # Проверка DPI: ищем наше правило на позиции 1 или наличие цепочки ZALP_DPI с правилами
    if iptables -t mangle -C PREROUTING -j ZALP_DPI 2>/dev/null && iptables -t mangle -C ZALP_DPI -p tcp --dport 443 -j NFQUEUE --queue-num 1 2>/dev/null; then
        dpi="🟢"
    fi
    
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

# Обработка аргументов командной строки (для вызова вне меню)
if [ "$1" = "start" ]; then
    systemctl start nfqws
    apply_zalp_rules
    echo -e "${GREEN}✓ Обход DPI запущен.${NC}"
    exit 0
elif [ "$1" = "stop" ]; then
    remove_zalp_rules
    systemctl stop nfqws
    echo -e "${YELLOW}✓ Обход DPI остановлен.${NC}"
    exit 0
elif [ "$1" = "restart" ]; then
    $0 stop
    sleep 1
    $0 start
    exit 0
elif [ "$1" = "status" ]; then
    systemctl status nfqws --no-pager
    echo "--- Правила ZALP_DPI ---"
    iptables -t mangle -L ZALP_DPI -n -v 2>/dev/null || echo "Цепочка не найдена"
    exit 0
elif [ "$1" = "doctor" ]; then
    echo -e "${CYAN}  Запуск Zalp Doctor...${NC}"
    if ! systemctl is-active --quiet nfqws; then
        echo -e "${YELLOW}  ⚠️  nfqws не активен. Перезапуск...${NC}"
        systemctl restart nfqws
    fi
    apply_zalp_rules # Принудительно возвращаем правила на место!
    
    # Проверка IP forwarding
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" -ne 1 ]; then
        sysctl -w net.ipv4.ip_forward=1 > /dev/null
    fi
    
    echo -e "${GREEN}  ✓ Доктор завершил работу. Система стабильна.${NC}"
    exit 0
elif [ "$1" = "check" ]; then
    $0 status
    echo -e "${CYAN}  Проверка доступности сети...${NC}"
    ping -c 2 8.8.8.8 > /dev/null && echo -e "${GREEN}  ✓ Интернет доступен${NC}" || echo -e "${RED}  ✗ Нет доступа к интернету${NC}"
    exit 0
fi

# Интерактивное меню
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
        1) $0 status; pause ;;
        2) $0 check; pause ;;
        3) $0 start; pause ;;
        4) $0 stop; pause ;;
        5) $0 restart; pause ;;
        6) $0 doctor; pause ;;
        7) tail -30 /var/log/zalp-doctor.log 2>/dev/null || echo "  Лог пуст"; pause ;;
        8) 
            if [ -x /usr/local/bin/mihomo-start ]; then
                echo "  Выберите действие для Mihomo:"
                echo "  a) Запустить (mihomo-start)"
                echo "  b) Остановить (mihomo-stop)"
                echo "  c) Перезапустить (mihomo-restart)"
                read -rp "  Выбор [a/b/c]: " m_choice
                case "$m_choice" in
                    a) mihomo-start; $0 doctor ;; # После запуска Mihomo, сразу лечим Zalp
                    b) mihomo-stop ;;
                    c) mihomo-restart; $0 doctor ;;
                    *) echo "  Неверный выбор." ;;
                esac
            else
                echo -e "${YELLOW}  Mihomo не установлен.${NC}"
            fi
            pause ;;
        9)
            if iptables -t mangle -L 2>/dev/null | grep -q "TV_VPN_FIX"; then
                echo "  Выберите действие для TV Fix:"
                echo "  a) Запустить (fix start)"
                echo "  b) Остановить (fix stop)"
                echo "  c) Перезапустить (fix restart)"
                read -rp "  Выбор [a/b/c]: " t_choice
                case "$t_choice" in
                    a) fix start; $0 doctor ;;
                    b) fix stop ;;
                    c) fix restart; $0 doctor ;;
                    *) echo "  Неверный выбор." ;;
                esac
            else
                echo -e "${YELLOW}  TV Fix не установлен.${NC}"
            fi
            pause ;;
        10)
            echo -e "${CYAN}  Запуск blockcheck.sh...${NC}"
            if [ -f /opt/zalp/blockcheck.sh ]; then
                cd /opt/zalp && sudo ./blockcheck.sh
            else
                echo -e "${RED}  ✗ Скрипт blockcheck.sh не найден.${NC}"
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