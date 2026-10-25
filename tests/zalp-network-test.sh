#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║     Zalp Network Path & Traffic Test Suite v1.0      ║
# ║  Диагностика пути трафика: Провайдер → Роутер → Zalp ║
# ╚══════════════════════════════════════════════════════╝

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Этот тест нужно запускать через sudo${NC}"
    exit 1
fi

# Цветные разделители
separator() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

header() {
    echo ""
    separator
    echo -e "${CYAN}  $1${NC}"
    separator
}

# ============================================================
# ЭТАП 0: Информация о системе и топологии сети
# ============================================================
header "🌐 ЭТАП 0: Топология сети и интерфейсы"
echo -e "${YELLOW}  Схема: [Провайдер] ──▶ [Роутер] ──▶ [Сервер с Zalp] ──▶ [Клиенты]${NC}"
echo ""

# Определяем WAN интерфейс (куда идет трафик к провайдеру)
WAN_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
WAN_IP=$(ip addr show $WAN_IFACE 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
WAN_GW=$(ip route | grep default | awk '{print $3}' | head -1)

echo -e "${BLUE}📡 WAN (внешний интерфейс, связь с роутером/провайдером):${NC}"
echo -e "   • Интерфейс: ${GREEN}$WAN_IFACE${NC}"
echo -e "   • IP-адрес:  ${GREEN}$WAN_IP${NC}"
echo -e "   • Шлюз:      ${GREEN}$WAN_GW${NC} ← это ваш роутер"
echo ""

# Определяем LAN интерфейсы (куда подключены клиенты)
echo -e "${BLUE}🏠 LAN (внутренние интерфейсы для клиентов):${NC}"
LAN_IFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "^lo$" | grep -v "^$WAN_IFACE$" | grep -v "^docker" | grep -v "^br-" | grep -v "^veth")
if [ -z "$LAN_IFACES" ]; then
    echo -e "   ${YELLOW}⚠️  Не найдено отдельных LAN интерфейсов${NC}"
    echo -e "   ${YELLOW}   Возможно, сервер и клиенты в одной подсети через роутер${NC}"
else
    for iface in $LAN_IFACES; do
        ip_addr=$(ip addr show $iface 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        if [ -n "$ip_addr" ]; then
            echo -e "   • ${GREEN}$iface${NC} → IP: ${GREEN}$ip_addr${NC}"
        fi
    done
fi
echo ""

# IP-адрес сервера (для клиентов)
SERVER_IP=$(hostname -I | awk '{print $1}')
echo -e "${BLUE}🖥  IP-адрес сервера с Zalp: ${GREEN}$SERVER_IP${NC}"
echo -e "   ${YELLOW}Клиенты должны иметь: Шлюз=$SERVER_IP, DNS=$SERVER_IP${NC}"

# ============================================================
# ЭТАП 1: Проверка связности на каждом этапе
# ============================================================
header "🔗 ЭТАП 1: Проверка связности по цепочке"

echo -e "${BLUE}  [1] Сервер → Локальный стек (проверка работы сети)${NC}"
if ping -c 2 -W 2 127.0.0.1 > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓ Петля работает (127.0.0.1)${NC}"
else
    echo -e "   ${RED}✗ Проблема с локальным стеком!${NC}"
fi

echo ""
echo -e "${BLUE}  [2] Сервер → Роутер (шлюз по умолчанию)${NC}"
if [ -n "$WAN_GW" ]; then
    if ping -c 3 -W 2 $WAN_GW > /dev/null 2>&1; then
        echo -e "   ${GREEN}✓ Роутер ($WAN_GW) доступен${NC}"
        echo -e "   ${YELLOW}   Пакеты доходят от сервера до роутера${NC}"
    else
        echo -e "   ${RED}✗ Роутер ($WAN_GW) НЕ отвечает!${NC}"
        echo -e "   ${RED}   Проверьте кабель между сервером и роутером${NC}"
    fi
fi

echo ""
echo -e "${BLUE}  [3] Сервер → Интернет (через роутер к провайдеру)${NC}"
if ping -c 3 -W 3 8.8.8.8 > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓ Интернет доступен (8.8.8.8 отвечает)${NC}"
    echo -e "   ${YELLOW}   Маршрут: Сервер → Роутер → Провайдер → Google DNS${NC}"
else
    echo -e "   ${RED}✗ Интернет НЕ доступен!${NC}"
fi

echo ""
echo -e "${BLUE}  [4] Проверка DNS (преобразование имен)${NC}"
if nslookup google.com > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓ DNS работает${NC}"
else
    echo -e "   ${RED}✗ DNS не отвечает!${NC}"
fi

# ============================================================
# ЭТАП 2: Трассировка пути пакетов (traceroute)
# ============================================================
header "🛤  ЭТАП 2: Трассировка пути пакетов (куда идет трафик)"

echo -e "${BLUE}  Трассируем путь до Google DNS (8.8.8.8)...${NC}"
echo -e "${YELLOW}  Это покажет каждый роутер на пути от сервера до цели${NC}"
echo ""

if command -v traceroute > /dev/null 2>&1; then
    traceroute -n -m 10 -w 2 8.8.8.8 2>/dev/null | head -12 | while read line; do
        echo -e "   $line"
    done
elif command -v tracepath > /dev/null 2>&1; then
    tracepath -n 8.8.8.8 2>/dev/null | head -12 | while read line; do
        echo -e "   $line"
    done
else
    echo -e "   ${YELLOW}⚠️  Установите traceroute: apt install traceroute${NC}"
fi

echo ""
echo -e "${BLUE}  📌 Расшифровка:${NC}"
echo -e "   ${YELLOW}• Строка 1: обычно это ваш роутер (шлюз)${NC}"
echo -e "   ${YELLOW}• Строка 2-3: оборудование провайдера${NC}"
echo -e "   ${YELLOW}• Далее: магистральные маршрутизаторы${NC}"
echo -e "   ${YELLOW}• Последняя строка: конечный сервер (8.8.8.8)${NC}"

# ============================================================
# ЭТАП 3: Проверка работы DPI-обхода (Zalp)
# ============================================================
header "🛡  ЭТАП 3: Проверка работы DPI-обхода (Zalp)"

echo -e "${BLUE}  Проверяем доступность заблокированных ресурсов...${NC}"
echo ""

# Функция проверки сайта
check_site() {
    local domain=$1
    local desc=$2
    echo -n "   • $desc ($domain): "
    
    # Пытаемся подключиться по HTTPS
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "https://$domain" 2>/dev/null | grep -qE "^(200|301|302|403|404)"; then
        echo -e "${GREEN}✓ ДОСТУПЕН${NC}"
        return 0
    else
        echo -e "${RED}✗ НЕДОСТУПЕН${NC}"
        return 1
    fi
}

SITES_OK=0
SITES_TOTAL=0

# Проверяем основные сервисы
for site in "youtube.com" "instagram.com" "facebook.com" "google.com"; do
    SITES_TOTAL=$((SITES_TOTAL + 1))
    if check_site "$site" "$site"; then
        SITES_OK=$((SITES_OK + 1))
    fi
done

echo ""
echo -e "${BLUE}  📊 Итог: ${GREEN}$SITES_OK из $SITES_TOTAL${NC} ресурсов доступны"

if [ $SITES_OK -eq $SITES_TOTAL ]; then
    echo -e "   ${GREEN}✓ DPI-обход работает корректно!${NC}"
elif [ $SITES_OK -gt 0 ]; then
    echo -e "   ${YELLOW}⚠️  Часть ресурсов недоступна. Возможно, нужна новая стратегия.${NC}"
    echo -e "   ${YELLOW}   Запустите: sudo zalp test${NC}"
else
    echo -e "   ${RED}✗ DPI-обход не работает!${NC}"
    echo -e "   ${RED}   Запустите: sudo zalp doctor${NC}"
fi

# ============================================================
# ЭТАП 4: Анализ правил iptables (как трафик обрабатывается)
# ============================================================
header "🔥 ЭТАП 4: Правила iptables (как трафик обрабатывается)"

echo -e "${BLUE}  Показываем правила, через которые проходит трафик...${NC}"
echo ""

# Проверяем цепочку ZALP_DPI
echo -e "${YELLOW}  📌 Цепочка ZALP_DPI (основной DPI-обход):${NC}"
if iptables -t mangle -L ZALP_DPI -n -v 2>/dev/null | grep -q "NFQUEUE"; then
    echo -e "   ${GREEN}✓ Цепочка существует и активна${NC}"
    echo ""
    iptables -t mangle -L ZALP_DPI -n -v 2>/dev/null | grep -E "(pkts|NFQUEUE|dpt:)" | while read line; do
        echo -e "   ${CYAN}$line${NC}"
    done
    echo ""
    echo -e "   ${YELLOW}   📖 Расшифровка:${NC}"
    echo -e "   ${YELLOW}   • pkts/bytes: сколько пакетов обработано${NC}"
    echo -e "   ${YELLOW}   • NFQUEUE: пакеты отправляются в nfqws для обхода DPI${NC}"
    echo -e "   ${YELLOW}   • dpt:80/443: порты HTTP/HTTPS${NC}"
else
    echo -e "   ${RED}✗ Цепочка ZALP_DPI не найдена!${NC}"
    echo -e "   ${RED}   Запустите: sudo zalp doctor${NC}"
fi

echo ""
echo -e "${YELLOW}  📌 Прыжок из PREROUTING в ZALP_DPI:${NC}"
if iptables -t mangle -L PREROUTING -n -v 2>/dev/null | grep -q "ZALP_DPI"; then
    echo -e "   ${GREEN}✓ Прыжок установлен${NC}"
    iptables -t mangle -L PREROUTING -n --line-numbers 2>/dev/null | grep "ZALP_DPI" | head -3 | while read line; do
        echo -e "   ${CYAN}   $line${NC}"
    done
    echo ""
    echo -e "   ${YELLOW}   📖 Это значит: ВЕСЬ входящий трафик сначала${NC}"
    echo -e "   ${YELLOW}   попадает в ZALP_DPI для обработки DPI-обходом${NC}"
else
    echo -e "   ${RED}✗ Прыжок не установлен!${NC}"
fi

echo ""
echo -e "${YELLOW}  📌 NAT (Masquerade) — выход в интернет:${NC}"
if iptables -t nat -L POSTROUTING -n -v 2>/dev/null | grep -q "MASQUERADE"; then
    echo -e "   ${GREEN}✓ NAT работает (клиенты могут выходить в интернет)${NC}"
    iptables -t nat -L POSTROUTING -n -v 2>/dev/null | grep "MASQUERADE" | head -2 | while read line; do
        echo -e "   ${CYAN}   $line${NC}"
    done
else
    echo -e "   ${RED}✗ NAT не настроен!${NC}"
fi

# ============================================================
# ЭТАП 5: Проверка работы сервиса nfqws
# ============================================================
header "⚙️  ЭТАП 5: Статус сервиса nfqws (движок DPI-обхода)"

echo -e "${BLUE}  Проверяем, работает ли основной процесс...${NC}"
echo ""

if systemctl is-active --quiet nfqws 2>/dev/null; then
    echo -e "   ${GREEN}✓ Сервис nfqws активен${NC}"
    echo ""
    systemctl status nfqws 2>/dev/null | grep -E "(Active|Memory|CPU|Tasks)" | while read line; do
        echo -e "   ${CYAN}$line${NC}"
    done
    echo ""
    
    # Проверяем процесс
    NFQWS_PID=$(pgrep -f "nfqws.*--qnum=1" | head -1)
    if [ -n "$NFQWS_PID" ]; then
        echo -e "   ${GREEN}✓ Процесс nfqws запущен (PID: $NFQWS_PID)${NC}"
        echo -e "   ${YELLOW}   Он обрабатывает пакеты из очереди NFQUEUE №1${NC}"
    else
        echo -e "   ${RED}✗ Процесс nfqws не найден!${NC}"
    fi
else
    echo -e "   ${RED}✗ Сервис nfqws НЕ активен!${NC}"
    echo -e "   ${RED}   Запустите: sudo zalp start${NC}"
fi

# ============================================================
# ЭТАП 6: Проверка IP Forwarding (маршрутизация)
# ============================================================
header "🔀 ЭТАП 6: Проверка маршрутизации (IP Forwarding)"

echo -e "${BLUE}  Может ли сервер пересылать пакеты между клиентами и интернетом?${NC}"
echo ""

IPV4_FWD=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
IPV6_FWD=$(cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null)

if [ "$IPV4_FWD" = "1" ]; then
    echo -e "   ${GREEN}✓ IPv4 forwarding включен${NC}"
    echo -e "   ${YELLOW}   Сервер может пересылать пакеты клиентов в интернет${NC}"
else
    echo -e "   ${RED}✗ IPv4 forwarding выключен!${NC}"
    echo -e "   ${RED}   Клиенты НЕ смогут выходить в интернет через сервер${NC}"
fi

if [ "$IPV6_FWD" = "1" ]; then
    echo -e "   ${GREEN}✓ IPv6 forwarding включен${NC}"
else
    echo -e "   ${YELLOW}⚠️  IPv6 forwarding выключен (не критично)${NC}"
fi

# ============================================================
# ЭТАП 7: Проверка модулей Mihomo и TV Fix (если установлены)
# ============================================================
header "🌐 ЭТАП 7: Проверка дополнительных модулей"

# Mihomo
echo -e "${BLUE}  📡 Модуль Mihomo (прозрачный прокси):${NC}"
if command -v mihomo &> /dev/null && systemctl is-active --quiet mihomo 2>/dev/null; then
    echo -e "   ${GREEN}✓ Mihomo установлен и работает${NC}"
    
    # Проверяем порты
    if ss -tlnp 2>/dev/null | grep -q ":7890 "; then
        echo -e "   ${GREEN}   • Порт 7890 (HTTP/SOCKS прокси): активен${NC}"
    fi
    if ss -tlnp 2>/dev/null | grep -q ":7892 "; then
        echo -e "   ${GREEN}   • Порт 7892 (TPROXY): активен${NC}"
    fi
    if ss -tlnp 2>/dev/null | grep -q ":1053 "; then
        echo -e "   ${GREEN}   • Порт 1053 (DNS резолвер): активен${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠️  Mihomo не установлен или не запущен${NC}"
fi

echo ""

# TV Fix
echo -e "${BLUE}  📺 Модуль TV Fix VPN (прозрачный VPN для ТВ):${NC}"
if command -v fix &> /dev/null; then
    echo -e "   ${GREEN}✓ TV Fix установлен${NC}"
    
    # Проверяем цепочку TV_VPN_FIX
    if iptables -t mangle -L TV_VPN_FIX -n 2>/dev/null | grep -q "Chain"; then
        echo -e "   ${GREEN}   • Правила перехвата активны${NC}"
        echo -e "   ${YELLOW}     Трафик ТВ перенаправляется через VPN${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠️  TV Fix не установлен${NC}"
fi

# ============================================================
# ЭТАП 8: Статистика пакетов (сколько трафика обработано)
# ============================================================
header "📊 ЭТАП 8: Статистика обработанных пакетов"

echo -e "${BLUE}  Сколько пакетов прошло через DPI-обход?${NC}"
echo ""

# Считаем общую статистику из цепочки ZALP_DPI
TOTAL_PKTS=$(iptables -t mangle -L ZALP_DPI -n -v 2>/dev/null | awk 'NR>2 {sum+=$1} END {print sum+0}')
TOTAL_BYTES=$(iptables -t mangle -L ZALP_DPI -n -v 2>/dev/null | awk 'NR>2 {sum+=$2} END {print sum+0}')

if [ "$TOTAL_PKTS" -gt 0 ]; then
    # Конвертируем байты в читаемый формат
    if [ "$TOTAL_BYTES" -gt 1073741824 ]; then
        SIZE=$(echo "scale=2; $TOTAL_BYTES/1073741824" | bc)
        SIZE_UNIT="ГБ"
    elif [ "$TOTAL_BYTES" -gt 1048576 ]; then
        SIZE=$(echo "scale=2; $TOTAL_BYTES/1048576" | bc)
        SIZE_UNIT="МБ"
    else
        SIZE=$(echo "scale=2; $TOTAL_BYTES/1024" | bc)
        SIZE_UNIT="КБ"
    fi
    
    echo -e "   ${GREEN}✓ Обработано пакетов: ${CYAN}$TOTAL_PKTS${NC}"
    echo -e "   ${GREEN}✓ Объем трафика: ${CYAN}$SIZE $SIZE_UNIT${NC}"
    echo ""
    echo -e "   ${YELLOW}   📖 Это трафик, который прошел через DPI-обход${NC}"
    echo -e "   ${YELLOW}   (YouTube, Instagram, Facebook и другие сервисы)${NC}"
else
    echo -e "   ${YELLOW}⚠️  Статистика пуста (0 пакетов)${NC}"
    echo -e "   ${YELLOW}   Возможно, DPI-обход только что запущен${NC}"
fi

# ============================================================
# ЭТАП 9: Финальная проверка (ping с разных интерфейсов)
# ============================================================
header "🏁 ЭТАП 9: Финальная проверка (ping пакетов)"

echo -e "${BLUE}  Отправляем тестовые пакеты и проверяем отклики...${NC}"
echo ""

# Ping до шлюза (роутера)
echo -e "${YELLOW}  [1] Ping до роутера ($WAN_GW):${NC}"
ping -c 5 -W 2 $WAN_GW 2>/dev/null | tail -2 | while read line; do
    echo -e "   ${CYAN}$line${NC}"
done

echo ""

# Ping до внешнего хоста
echo -e "${YELLOW}  [2] Ping до Google DNS (8.8.8.8):${NC}"
ping -c 5 -W 3 8.8.8.8 2>/dev/null | tail -2 | while read line; do
    echo -e "   ${CYAN}$line${NC}"
done

echo ""

# Ping до заблокированного ресурса (если DPI работает)
echo -e "${YELLOW}  [3] Ping до youtube.com (проверка DPI-обхода):${NC}"
if ping -c 3 -W 3 youtube.com > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓ youtube.com отвечает (DPI-обход работает)${NC}"
    ping -c 3 -W 3 youtube.com 2>/dev/null | tail -2 | while read line; do
        echo -e "   ${CYAN}$line${NC}"
    done
else
    echo -e "   ${YELLOW}⚠️  youtube.com не отвечает на ping${NC}"
    echo -e "   ${YELLOW}   (это нормально, многие сайты блокируют ICMP)${NC}"
fi

# ============================================================
# ИТОГОВЫЙ ОТЧЕТ
# ============================================================
header "📋 ИТОГОВЫЙ ОТЧЕТ"

echo ""
echo -e "${BLUE}  🌐 Путь трафика в вашей сети:${NC}"
echo ""
echo -e "   ${GREEN}[Клиенты]${NC} (телефоны, ноутбуки, ТВ)"
echo -e "        │"
echo -e "        ▼"
echo -e "   ${GREEN}[Сервер с Zalp]${NC} ($SERVER_IP)"
echo -e "        │"
echo -e "        ├─▶ ${YELLOW}iptables ZALP_DPI${NC} (DPI-обход)"
echo -e "        ├─▶ ${YELLOW}nfqws${NC} (обработка пакетов)"
echo -e "        ├─▶ ${YELLOW}NAT/Masquerade${NC} (выход в интернет)"
echo -e "        │"
echo -e "        ▼"
echo -e "   ${GREEN}[Роутер]${NC} ($WAN_GW)"
echo -e "        │"
echo -e "        ▼"
echo -e "   ${GREEN}[Провайдер]${NC}"
echo -e "        │"
echo -e "        ▼"
echo -e "   ${GREEN}[Интернет]${NC}"
echo ""
separator

echo -e "${GREEN}  ✓ Тест завершен!${NC}"
echo ""
echo -e "${YELLOW}  Рекомендации:${NC}"
echo -e "   • Если DPI-обход не работает: ${CYAN}sudo zalp doctor${NC}"
echo -e "   • Если нужна новая стратегия: ${CYAN}sudo zalp test${NC}"
echo -e "   • Для управления: ${CYAN}sudo zalp${NC}"
echo ""