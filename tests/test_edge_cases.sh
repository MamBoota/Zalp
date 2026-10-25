#!/bin/bash
# Тест: Проверка пограничных случаев
# Сценарии:
# 1. Попытка добавить дубликат правила ZALP_DPI
# 2. Запуск zalp start/stop/restart
# 3. Проверка после перезапуска nfqws

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функция для определения ожидаемой позиции
get_expected_pos() {
    if iptables -t mangle -L PREROUTING -n | grep -q "TV_VPN_FIX"; then
        echo 2
    else
        echo 1
    fi
}

echo -e "${YELLOW}[TEST] Проверка пограничных случаев...${NC}"

# Тест 1: Попытка добавить дубликат правила и проверка его удаления
echo -e "${CYAN}  Тест 1: Попытка добавления дубликата правила и очистка...${NC}"
# Намеренно добавляем дубликат прыжка
iptables -t mangle -I PREROUTING -j ZALP_DPI 2>/dev/null || true
iptables -t mangle -I PREROUTING -j ZALP_DPI 2>/dev/null || true

# Проверяем, что дубликаты есть (должно быть > 1)
DUP_COUNT=$(iptables -t mangle -L PREROUTING -n | grep -c "ZALP_DPI" || echo 0)
if [ "$DUP_COUNT" -le 1 ]; then
    echo -e "${YELLOW}  ⚠ Не удалось создать дубликат для теста, пропускаем проверку очистки${NC}"
else
    # Запускаем doctor, который должен оставить только ОДИН прыжок
    /usr/local/bin/zalp doctor >/dev/null 2>&1
    AFTER_DOCTOR=$(iptables -t mangle -L PREROUTING -n | grep -c "ZALP_DPI" || echo 0)
    if [ "$AFTER_DOCTOR" -ne 1 ]; then
        echo -e "${RED}✗ FAIL: zalp doctor не удалил дубликаты (осталось: $AFTER_DOCTOR)${NC}"
        exit 1
    fi
fi

# Тест 2: Запуск zalp stop и проверка
echo -e "${CYAN}  Тест 2: Проверка zalp stop...${NC}"
/usr/local/bin/zalp stop >/dev/null 2>&1
sleep 1
if iptables -t mangle -C PREROUTING -j ZALP_DPI >/dev/null 2>&1; then
    echo -e "${RED}✗ FAIL: После zalp stop правила ZALP_DPI остались в PREROUTING${NC}"
    exit 1
fi

# Тест 3: Запуск zalp start и проверка
echo -e "${CYAN}  Тест 3: Проверка zalp start...${NC}"
/usr/local/bin/zalp start >/dev/null 2>&1
sleep 1
if ! iptables -t mangle -C PREROUTING -j ZALP_DPI >/dev/null 2>&1; then
    echo -e "${RED}✗ FAIL: После zalp start правила ZALP_DPI отсутствуют${NC}"
    exit 1
fi

EXPECTED_POS=$(get_expected_pos)
ACTUAL_POS=$(iptables -t mangle -L PREROUTING -n --line-numbers | grep "ZALP_DPI" | awk '{print $1}')
if [ "$ACTUAL_POS" != "$EXPECTED_POS" ]; then
    echo -e "${RED}✗ FAIL: После zalp start правила ZALP_DPI на позиции $ACTUAL_POS (ожидалось: $EXPECTED_POS)${NC}"
    exit 1
fi

# Тест 4: Перезапуск nfqws
echo -e "${CYAN}  Тест 4: Проверка после перезапуска nfqws...${NC}"
systemctl restart nfqws
sleep 2
/usr/local/bin/zalp doctor >/dev/null 2>&1

EXPECTED_POS=$(get_expected_pos)
ACTUAL_POS=$(iptables -t mangle -L PREROUTING -n --line-numbers | grep "ZALP_DPI" | awk '{print $1}')
if [ "$ACTUAL_POS" != "$EXPECTED_POS" ]; then
    echo -e "${RED}✗ FAIL: После перезапуска nfqws правила ZALP_DPI на позиции $ACTUAL_POS (ожидалось: $EXPECTED_POS)${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: Все пограничные случаи пройдены${NC}"
exit 0