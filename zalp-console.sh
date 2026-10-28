#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║        Zalp Unified Management Console v5.3          ║
# ║           Рефакторинг + Hot Restart + Новое меню     ║
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

# ═══════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (устраняют дублирование кода)
# ═══════════════════════════════════════════════════════

run_both() {
    iptables "$@" 2>/dev/null || true
    ip6tables "$@" 2>/dev/null || true
}

ensure_chain() {
    local table=$1 chain=$2
    iptables -t "$table" -N "$chain" 2>/dev/null || true
    ip6tables -t "$table" -N "$chain" 2>/dev/null || true
}

remove_jumps() {
    local table=$1 from=$2 to=$3
    while iptables -t "$table" -D "$from" -j "$to" 2>/dev/null; do :; done
    while ip6tables -t "$table" -D "$from" -j "$to" 2>/dev/null; do :; done
}

destroy_chain() {
    local table=$1 chain=$2
    iptables -t "$table" -F "$chain" 2>/dev/null || true
    ip6tables -t "$table" -F "$chain" 2>/dev/null || true
    iptables -t "$table" -X "$chain" 2>/dev/null || true
    ip6tables -t "$table" -X "$chain" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════
# ПРАВИЛА IPTABLES
# ═══════════════════════════════════════════════════════

apply_zalp_rules() {
    echo -e "${CYAN}  Применение правил iptables...${NC}"
    
    ensure_chain mangle ZALP_DPI
    
    iptables -t mangle -F ZALP_DPI
    ip6tables -t mangle -F ZALP_DPI
    
    for port in 80 443; do
        iptables -t mangle -A ZALP_DPI -p tcp --dport "$port" -j NFQUEUE --queue-num 1
        ip6tables -t mangle -A ZALP_DPI -p tcp --dport "$port" -j NFQUEUE --queue-num 1
    done
    iptables -t mangle -A ZALP_DPI -p udp --dport 443 -j NFQUEUE --queue-num 1
    ip6tables -t mangle -A ZALP_DPI -p udp --dport 443 -j NFQUEUE --queue-num 1
    
    remove_jumps mangle PREROUTING ZALP_DPI
    iptables -t mangle -I PREROUTING 2 -j ZALP_DPI
    ip6tables -t mangle -I PREROUTING 2 -j ZALP_DPI
    
    echo -e "${GREEN}  ✓ Правила установлены (Zalp на позиции 2)${NC}"
}

remove_zalp_rules() {
    remove_jumps mangle PREROUTING ZALP_DPI
    destroy_chain mangle ZALP_DPI
}

# ═══════════════════════════════════════════════════════
# ПРОВЕРКИ СТАТУСОВ
# ═══════════════════════════════════════════════════════

check_internet() {
    # Проверка доступности + потери пакетов (прямой канал)
    local ping_result
    ping_result=$(ping -c 10 -W 2 -i 0.2 8.8.8.8 2>&1)
    local packet_loss
    packet_loss=$(echo "$ping_result" | grep -oP '\d+(?=% packet loss)' || echo "100")
    
    if [ "$packet_loss" = "100" ]; then
        echo "🔴 Интернет (провайдер) — НЕ доступен"
        echo "   Потери пакетов: 100%"
        return 1
    fi
    
    # Замер входящей скорости (download) - 1MB от Cloudflare
    local speed_download_bytes
    speed_download_bytes=$(curl -o /dev/null -w "%{speed_download}" -s "https://speed.cloudflare.com/__down?bytes=1000000" --max-time 6 2>/dev/null || echo "0")
    local speed_download_mbps
    speed_download_mbps=$(awk "BEGIN {printf \"%.2f\", $speed_download_bytes * 8 / 1000000}")
    
    # Замер исходящей скорости (upload) - 1MB на Cloudflare
    local speed_upload_bytes
    speed_upload_bytes=$(dd if=/dev/zero bs=1M count=1 2>/dev/null | curl -X POST --data-binary @- -o /dev/null -w "%{speed_upload}" -s "https://speed.cloudflare.com/__up" --max-time 6 2>/dev/null || echo "0")
    local speed_upload_mbps
    speed_upload_mbps=$(awk "BEGIN {printf \"%.2f\", $speed_upload_bytes * 8 / 1000000}")
    
    # Формируем цветовой статус
    local color="${GREEN}"
    local status_text="доступен"
    if [ "$packet_loss" != "0" ]; then
        color="${YELLOW}"
        status_text="доступен (нестабильно)"
    fi
    
    echo -e "${color}🟢 Интернет (провайдер) — ${status_text}${NC}"
    echo "   ↓ Входящая: ${speed_download_mbps} Мбит/с"
    echo "   ↑ Исходящая: ${speed_upload_mbps} Мбит/с"
    echo "   Потери пакетов: ${packet_loss}%"
    return 0
}

check_vpn_status() {
    # Проверяем, запущен ли Mihomo
    if [ ! -x /usr/local/bin/mihomo-start ] || ! systemctl is-active --quiet mihomo; then
        echo "⚪ VPN (Mihomo) — не активен"
        return 1
    fi
    
    # Получаем имя активного узла
    local node
    node=$(curl -s -m 2 http://127.0.0.1:9090/proxies/AUTO-FASTEST 2>/dev/null | grep -o '"now":"[^"]*"' | cut -d'"' -f4)
    if [ -z "$node" ]; then
        node="не определен"
    fi
    
    # Замер скорости через VPN (прокси 127.0.0.1:7890)
    local speed_download_bytes
    speed_download_bytes=$(curl -o /dev/null -w "%{speed_download}" -s -x http://127.0.0.1:7890 "https://speed.cloudflare.com/__down?bytes=1000000" --max-time 8 2>/dev/null || echo "0")
    local speed_download_mbps
    speed_download_mbps=$(awk "BEGIN {printf \"%.2f\", $speed_download_bytes * 8 / 1000000}")
    
    local speed_upload_bytes
    speed_upload_bytes=$(dd if=/dev/zero bs=1M count=1 2>/dev/null | curl -X POST --data-binary @- -o /dev/null -w "%{speed_upload}" -s -x http://127.0.0.1:7890 "https://speed.cloudflare.com/__up" --max-time 8 2>/dev/null || echo "0")
    local speed_upload_mbps
    speed_upload_mbps=$(awk "BEGIN {printf \"%.2f\", $speed_upload_bytes * 8 / 1000000}")
    
    # Замер пинга через VPN (время отклика)
    local ping_time
    ping_time=$(curl -o /dev/null -s -w "%{time_starttransfer}" -x http://127.0.0.1:7890 "https://www.google.com" --max-time 5 2>/dev/null || echo "0")
    local ping_ms
    ping_ms=$(awk "BEGIN {printf \"%.0f\", $ping_time * 1000}")
    
    echo "🟢 VPN (Mihomo → ${node})"
    echo "   ↓ Входящая: ${speed_download_mbps} Мбит/с"
    echo "   ↑ Исходящая: ${speed_upload_mbps} Мбит/с"
    echo "   Пинг: ${ping_ms} мс"
    return 0
}

check_zalp_status() {
    if systemctl is-active --quiet nfqws && \
       iptables -t mangle -C PREROUTING -j ZALP_DPI 2>/dev/null && \
       iptables -t mangle -C ZALP_DPI -p tcp --dport 443 -j NFQUEUE --queue-num 1 2>/dev/null; then
        echo "🟢 Zalp — работает (nfqws активен, правила на месте)"
        return 0
    else
        echo "🔴 Zalp — НЕ работает"
        return 1
    fi
}

check_mihomo_status() {
    if [ -x /usr/local/bin/mihomo-start ] && systemctl is-active --quiet mihomo; then
        local node
        node=$(curl -s -m 2 http://127.0.0.1:9090/proxies/AUTO-FASTEST 2>/dev/null | grep -o '"now":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$node" ]; then
            echo "🟢 Mihomo — работает (узел: $node)"
        else
            echo "🟢 Mihomo — работает (узел определяется...)"
        fi
        return 0
    elif [ -x /usr/local/bin/mihomo-start ]; then
        echo "🔴 Mihomo — установлен, но НЕ активен"
        return 1
    else
        echo "⚪ Mihomo — не установлен"
        return 2
    fi
}

check_tvfix_status() {
    if iptables -t mangle -L TV_VPN_FIX 2>/dev/null | grep -q "TPROXY"; then
        local mac_count
        mac_count=$(iptables -t mangle -L TV_VPN_FIX -n 2>/dev/null | grep -c "mac source")
        echo "🟢 TV Fix — работает (перехвачено MAC: $mac_count)"
        return 0
    elif command -v fix &>/dev/null; then
        echo "🔴 TV Fix — установлен, но НЕ активен"
        return 1
    else
        echo "⚪ TV Fix — не установлен"
        return 2
    fi
}

# ═══════════════════════════════════════════════════════
# ОБНОВЛЕНИЯ
# ═══════════════════════════════════════════════════════

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

# ═══════════════════════════════════════════════════════
# БАННЕР
# ═══════════════════════════════════════════════════════

show_banner() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Zalp Unified Console v5.3                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo -e "  Версия продукта: ${CYAN}v$CURRENT_VERSION${NC}"
    
    local dpi="🔴" mih="⚪" tvf="⚪"
    if iptables -t mangle -C PREROUTING -j ZALP_DPI 2>/dev/null && \
       iptables -t mangle -C ZALP_DPI -p tcp --dport 443 -j NFQUEUE --queue-num 1 2>/dev/null; then
        dpi="🟢"
    fi
    [ -x /usr/local/bin/mihomo-start ] && systemctl is-active --quiet mihomo && mih="🟢"
    iptables -t mangle -L 2>/dev/null | grep -q "TV_VPN_FIX" && tvf="🟢"
    
    echo -e "  DPI: $dpi   Mihomo: $mih   TV Fix: $tvf"
    
    if [ "$UPDATE_AVAILABLE" = "1" ]; then
        echo -e "  ${YELLOW}⚠️  ДОСТУПНО ОБНОВЛЕНИЕ: v$(norm_ver "$REMOTE_TAG")${NC}"
    fi
    echo -e "${GREEN}────────────────────────────────────────────────────────${NC}"
}

# ═══════════════════════════════════════════════════════
# КОМАНДЫ МЕНЮ
# ═══════════════════════════════════════════════════════

cmd_status() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              СТАТУС СИСТЕМЫ                          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    check_internet
    echo ""
    check_vpn_status
    echo ""
    check_zalp_status
    check_tvfix_status
    echo ""
}

cmd_check() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         ПОЛНАЯ ТЕХНИЧЕСКАЯ ДИАГНОСТИКА (для ИИ)      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "📋 СИСТЕМНАЯ ИНФОРМАЦИЯ"
    echo "═══════════════════════════════════════════════════════"
    echo "Дата: $(date)"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -a)"
    echo "Uptime: $(uptime)"
    echo "Zalp version: $(cat /opt/zalp/VERSION 2>/dev/null || echo 'N/A')"
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "🌐 СЕТЕВЫЕ ИНТЕРФЕЙСЫ И МАРШРУТЫ"
    echo "═══════════════════════════════════════════════════════"
    echo "--- ip addr ---"
    ip addr show
    echo ""
    echo "--- ip route ---"
    ip route show
    echo ""
    echo "--- ip route show table 100 (TPROXY) ---"
    ip route show table 100 2>/dev/null || echo "(таблица 100 пуста)"
    echo ""
    echo "--- ip rule ---"
    ip rule show
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "⚙️  SYSCTL ПАРАМЕТРЫ"
    echo "═══════════════════════════════════════════════════════"
    sysctl net.ipv4.ip_forward
    sysctl net.ipv6.conf.all.forwarding
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "🔥 IPTABLES (полный дамп)"
    echo "═══════════════════════════════════════════════════════"
    echo "--- iptables-save ---"
    iptables-save 2>/dev/null
    echo ""
    echo "--- ip6tables-save ---"
    ip6tables-save 2>/dev/null
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "🛡️  СТАТУС СЕРВИСОВ"
    echo "═══════════════════════════════════════════════════════"
    echo "--- nfqws ---"
    systemctl status nfqws --no-pager -l 2>/dev/null || echo "(сервис не найден)"
    echo ""
    echo "--- mihomo ---"
    systemctl status mihomo --no-pager -l 2>/dev/null || echo "(сервис не найден)"
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "📜 ПОСЛЕДНИЕ ЛОГИ"
    echo "═══════════════════════════════════════════════════════"
    echo "--- journalctl -u nfqws -n 15 ---"
    journalctl -u nfqws -n 15 --no-pager 2>/dev/null || echo "(логов нет)"
    echo ""
    echo "--- journalctl -u mihomo -n 15 ---"
    journalctl -u mihomo -n 15 --no-pager 2>/dev/null || echo "(логов нет)"
    echo ""
    echo "--- /var/log/zalp-doctor.log (последние 20 строк) ---"
    tail -20 /var/log/zalp-doctor.log 2>/dev/null || echo "(лог пуст)"
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "📁 КОНФИГУРАЦИИ ZALP"
    echo "═══════════════════════════════════════════════════════"
    echo "--- /opt/zalp/domains.txt ---"
    cat /opt/zalp/domains.txt 2>/dev/null || echo "(файл не найден)"
    echo ""
    echo "--- /opt/zalp/domains-exclude.txt ---"
    cat /opt/zalp/domains-exclude.txt 2>/dev/null || echo "(файл не найден)"
    echo ""
    echo "--- /opt/zalp/tv_macs.conf ---"
    cat /opt/zalp/tv_macs.conf 2>/dev/null || echo "(файл не найден)"
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "⏰ CRON И ПРОЦЕССЫ"
    echo "═══════════════════════════════════════════════════════"
    echo "--- crontab -l ---"
    crontab -l 2>/dev/null || echo "(cron пуст)"
    echo ""
    echo "--- Процессы Zalp/Mihomo ---"
    ps aux | grep -E 'nfqws|mihomo|tpws' | grep -v grep
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "✅ ДИАГНОСТИКА ЗАВЕРШЕНА"
    echo "═══════════════════════════════════════════════════════"
}

cmd_full_restart() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     ПОЛНЫЙ ПЕРЕЗАПУСК (Hot Restart — без разрыва)    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}[1/5] Переключение в режим прямого доступа (hot restart)...${NC}"
    remove_zalp_rules
    [ -x /usr/local/bin/fix ] && fix stop 2>/dev/null || true
    echo -e "${GREEN}  ✓ Правила удалены, интернет работает напрямую${NC}"
    
    systemctl stop nfqws 2>/dev/null || true
    [ -x /usr/local/bin/mihomo-stop ] && mihomo-stop 2>/dev/null || true
    echo -e "${GREEN}  ✓ Все сервисы остановлены${NC}"
    echo ""
    
    echo -e "${YELLOW}[2/5] Запуск Zalp (nfqws)...${NC}"
    systemctl start nfqws
    sleep 1
    apply_zalp_rules
    echo -e "${GREEN}  ✓ Zalp запущен${NC}"
    echo ""
    
    echo -e "${YELLOW}[3/5] Запуск Mihomo...${NC}"
    if [ -x /usr/local/bin/mihomo-start ]; then
        mihomo-start
        sleep 2
        apply_zalp_rules # Принудительное восстановление приоритета после Mihomo
    else
        echo -e "${CYAN}  — Mihomo не установлен, пропуск${NC}"
    fi
    echo ""
    
    echo -e "${YELLOW}[4/5] Запуск TV Fix...${NC}"
    if command -v fix &>/dev/null; then
        fix start
    else
        echo -e "${CYAN}  — TV Fix не установлен, пропуск${NC}"
    fi
    echo ""
    
    echo -e "${YELLOW}[5/5] Финальная проверка...${NC}"
    cmd_status
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ ПОЛНЫЙ ПЕРЕЗАПУСК ЗАВЕРШЕН (Hot Restart OK)       ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
}

# ═══════════════════════════════════════════════════════
# ОБРАБОТКА CLI-АРГУМЕНТОВ
# ═══════════════════════════════════════════════════════

if [ -n "$1" ]; then
    case "$1" in
        start)
            systemctl start nfqws
            apply_zalp_rules
            echo -e "${GREEN}✓ Обход DPI запущен.${NC}"
            exit 0
            ;;
        stop)
            remove_zalp_rules
            systemctl stop nfqws
            echo -e "${YELLOW}✓ Обход DPI остановлен.${NC}"
            exit 0
            ;;
        restart)
            cmd_full_restart
            exit 0
            ;;
        status)
            cmd_status
            exit 0
            ;;
        check)
            cmd_check
            exit 0
            ;;
        doctor)
            echo -e "${CYAN}  Запуск Zalp Doctor...${NC}"
            if ! systemctl is-active --quiet nfqws; then
                systemctl restart nfqws
            fi
            apply_zalp_rules
            echo -e "${GREEN}  ✓ Доктор завершил работу. Система стабильна.${NC}"
            exit 0
            ;;
        *)
            echo "Использование: zalp {start|stop|restart|status|check|doctor}"
            exit 1
            ;;
    esac
fi

# ═══════════════════════════════════════════════════════
# ИНТЕРАКТИВНОЕ МЕНЮ
# ═══════════════════════════════════════════════════════

check_update

while true; do
    show_banner
    echo "  1) Статус системы"
    echo "  2) Полная диагностика (техническая информация)"
    echo "  3) Полный перезапуск (Zalp + Mihomo + TV Fix)"
    echo "  4) Логи Doctor"
    echo "  5) Тестирование стратегий (Blockcheck)"
    echo "  6) Проверить обновления"
    echo "  7) Установить обновление"
    echo "  0) Выход"
    echo " "
    read -rp "  Выбор: " choice
    
    case "$choice" in
        1) cmd_status; pause ;;
        2) cmd_check; pause ;;
        3) cmd_full_restart; pause ;;
        4) tail -30 /var/log/zalp-doctor.log 2>/dev/null || echo "  Лог пуст"; pause ;;
        5)
            echo -e "${CYAN}  Запуск blockcheck.sh...${NC}"
            if [ -f /opt/zalp/blockcheck.sh ]; then
                cd /opt/zalp && sudo ./blockcheck.sh
            else
                echo -e "${RED}  ✗ Скрипт blockcheck.sh не найден.${NC}"
            fi
            pause ;;
        6) 
            echo "  Проверка обновлений..."
            check_update
            if [ "$UPDATE_AVAILABLE" = "1" ]; then
                echo -e "  ${YELLOW}Доступна версия: v$(norm_ver "$REMOTE_TAG")${NC}"
            else
                echo -e "  ${GREEN}У вас последняя версия (v$CURRENT_VERSION)${NC}"
            fi
            pause ;;
        7) 
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