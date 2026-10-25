#!/bin/bash
# Тест: Проверка DNAT для DNS в TV_VPN_FIX

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Тест: Проверка DNAT для DNS в TV_VPN_FIX${NC}"

# Проверяем, установлен ли TV Fix
if ! command -v fix &> /dev/null; then
    echo -e "${YELLOW}⚠️  TV Fix не установлен, тест пропущен${NC}"
    exit 77  # Код пропуска теста
fi

# Проверяем, есть ли MAC-адреса в конфиге
if [ ! -f /opt/zalp/tv_macs.conf ]; then
    echo -e "${RED}✗ Файл /opt/zalp/tv_macs.conf не найден${NC}"
    exit 1
fi

# Считаем количество MAC-адресов (игнорируем комментарии и SERVER_IP)
mac_count=$(grep -v '^#' /opt/zalp/tv_macs.conf | grep -v '^SERVER_IP=' | grep -v '^$' | wc -l)

if [ "$mac_count" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  В конфиге нет MAC-адресов, тест пропущен${NC}"
    exit 77
fi

# Проверяем, есть ли DNAT правила для UDP 53
dnat_count=$(iptables -t nat -L TV_VPN_FIX -n -v 2>/dev/null | grep "DNAT" | grep "udp dpt:53" | wc -l)

if [ "$dnat_count" -eq 0 ]; then
    echo -e "${RED}✗ DNAT для DNS (UDP 53) не найден в TV_VPN_FIX${NC}"
    echo -e "${RED}  Телевизоры не смогут разрешать домены через Mihomo${NC}"
    exit 1
fi

if [ "$dnat_count" -ne "$mac_count" ]; then
    echo -e "${RED}✗ Количество DNAT правил ($dnat_count) не совпадает с количеством MAC-адресов ($mac_count)${NC}"
    exit 1
fi

echo -e "${GREEN}✓ DNAT для DNS настроен корректно ($dnat_count правил для $mac_count MAC-адресов)${NC}"
exit 0