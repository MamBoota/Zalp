#!/bin/bash
# Тест: Проверка приоритета правил ZALP_DPI в PREROUTING
# Ожидается: Правило "-j ZALP_DPI" должно быть на позиции 1 в цепочке PREROUTING

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[TEST] Проверка приоритета правил iptables...${NC}"

# Проверяем, что цепочка ZALP_DPI существует
if ! iptables -t mangle -L ZALP_DPI -n >/dev/null 2>&1; then
    echo -e "${RED}✗ FAIL: Цепочка ZALP_DPI не существует${NC}"
    exit 1
fi

# Проверяем, что в цепочке ZALP_DPI есть правила для NFQUEUE
if ! iptables -t mangle -C ZALP_DPI -p tcp --dport 443 -j NFQUEUE --queue-num 1 >/dev/null 2>&1; then
    echo -e "${RED}✗ FAIL: В цепочке ZALP_DPI отсутствуют правила NFQUEUE${NC}"
    exit 1
fi

# Проверяем, что прыжок в ZALP_DPI существует в PREROUTING
if ! iptables -t mangle -C PREROUTING -j ZALP_DPI >/dev/null 2>&1; then
    echo -e "${RED}✗ FAIL: Прыжок -j ZALP_DPI отсутствует в PREROUTING${NC}"
    exit 1
fi

# Проверяем, что прыжок в ZALP_DPI находится НА ПОЗИЦИИ 1 (или хотя бы до других правил)
FIRST_RULE=$(iptables -t mangle -L PREROUTING -n --line-numbers | grep -E "^\s*1\s+" | head -1)
if ! echo "$FIRST_RULE" | grep -q "ZALP_DPI"; then
    echo -e "${RED}✗ FAIL: Прыжок -j ZALP_DPI не на позиции 1 в PREROUTING${NC}"
    echo -e "${YELLOW}  Текущие правила PREROUTING:${NC}"
    iptables -t mangle -L PREROUTING -n --line-numbers
    exit 1
fi

echo -e "${GREEN}✓ PASS: Правила ZALP_DPI корректно установлены на позицию 1${NC}"
exit 0