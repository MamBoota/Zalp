#!/bin/bash
# Тест: Проверка, что запуск/остановка Mihomo не ломает правила Zalp
# Сценарий: Запускаем Mihomo, проверяем, что правила Zalp остались на месте

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

echo -e "${YELLOW}[TEST] Проверка конфликта с Mihomo...${NC}"

# Проверяем, что Mihomo установлен
if ! command -v mihomo-start >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ SKIP: Mihomo не установлен, тест пропущен${NC}"
    exit 0
fi

# Сохраняем текущее состояние правил
BEFORE_RULES=$(iptables -t mangle -L PREROUTING -n --line-numbers)

# Запускаем Mihomo
echo -e "${CYAN}  Запуск Mihomo...${NC}"
mihomo-start >/dev/null 2>&1 || true
sleep 3

# Проверяем позицию ZALP_DPI после запуска Mihomo
EXPECTED_POS=$(get_expected_pos)
ACTUAL_POS=$(iptables -t mangle -L PREROUTING -n --line-numbers | grep "ZALP_DPI" | awk '{print $1}')

if [ "$ACTUAL_POS" != "$EXPECTED_POS" ]; then
    echo -e "${RED}✗ FAIL: После запуска Mihomo ZALP_DPI на позиции $ACTUAL_POS (ожидалось: $EXPECTED_POS)${NC}"
    exit 1
fi
echo "✓ Mihomo не сломал порядок правил"

# Останавливаем Mihomo
echo -e "${CYAN}  Остановка Mihomo...${NC}"
mihomo-stop >/dev/null 2>&1 || true
sleep 2

# Проверяем, что правила Zalp всё ещё на месте после остановки
EXPECTED_POS=$(get_expected_pos)
ACTUAL_POS=$(iptables -t mangle -L PREROUTING -n --line-numbers | grep "ZALP_DPI" | awk '{print $1}')

if [ -z "$ACTUAL_POS" ]; then
    echo -e "${RED}✗ FAIL: После остановки Mihomo правила ZALP_DPI отсутствуют${NC}"
    exit 1
fi

if [ "$ACTUAL_POS" != "$EXPECTED_POS" ]; then
    echo -e "${RED}✗ FAIL: После остановки Mihomo ZALP_DPI на позиции $ACTUAL_POS (ожидалось: $EXPECTED_POS)${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: Mihomo не ломает правила Zalp${NC}"
exit 0