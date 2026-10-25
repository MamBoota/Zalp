#!/bin/bash
# Тест: Проверка, что запуск/остановка Mihomo не ломает правила Zalp
# Сценарий: Запускаем Mihomo, проверяем, что правила Zalp остались на месте

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Проверяем, что правила Zalp остались на позиции 1
FIRST_RULE=$(iptables -t mangle -L PREROUTING -n --line-numbers | grep -E "^\s*1\s+" | head -1)
if ! echo "$FIRST_RULE" | grep -q "ZALP_DPI"; then
    echo -e "${RED}✗ FAIL: После запуска Mihomo правила ZALP_DPI сдвинулись с позиции 1${NC}"
    echo -e "${YELLOW}  Правила до:${NC}"
    echo "$BEFORE_RULES"
    echo -e "${YELLOW}  Правила после:${NC}"
    iptables -t mangle -L PREROUTING -n --line-numbers
    mihomo-stop >/dev/null 2>&1 || true
    exit 1
fi

# Останавливаем Mihomo
echo -e "${CYAN}  Остановка Mihomo...${NC}"
mihomo-stop >/dev/null 2>&1 || true
sleep 2

# Проверяем, что правила Zalp всё ещё на месте
FIRST_RULE=$(iptables -t mangle -L PREROUTING -n --line-numbers | grep -E "^\s*1\s+" | head -1)
if ! echo "$FIRST_RULE" | grep -q "ZALP_DPI"; then
    echo -e "${RED}✗ FAIL: После остановки Mihomo правила ZALP_DPI отсутствуют${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: Mihomo не ломает правила Zalp${NC}"
exit 0