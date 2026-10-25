#!/bin/bash
# Тест: Проверка, что zalp doctor восстанавливает правила после их удаления
# Сценарий: Намеренно ломаем правила, запускаем doctor, проверяем восстановление

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[TEST] Проверка восстановления через zalp doctor...${NC}"

# Намеренно удаляем прыжок в ZALP_DPI из PREROUTING
echo -e "${CYAN}  Намеренное удаление правил ZALP_DPI из PREROUTING...${NC}"
iptables -t mangle -D PREROUTING -j ZALP_DPI 2>/dev/null || true
ip6tables -t mangle -D PREROUTING -j ZALP_DPI 2>/dev/null || true

# Проверяем, что правила действительно удалены
if iptables -t mangle -C PREROUTING -j ZALP_DPI >/dev/null 2>&1; then
    echo -e "${RED}✗ FAIL: Не удалось удалить правила для теста${NC}"
    exit 1
fi

# Запускаем zalp doctor
echo -e "${CYAN}  Запуск zalp doctor...${NC}"
/usr/local/bin/zalp doctor >/dev/null 2>&1

# Проверяем, что правила восстановились
if ! iptables -t mangle -C PREROUTING -j ZALP_DPI >/dev/null 2>&1; then
    echo -e "${RED}✗ FAIL: zalp doctor не восстановил правила ZALP_DPI${NC}"
    exit 1
fi

# Проверяем, что правила на позиции 1
FIRST_RULE=$(iptables -t mangle -L PREROUTING -n --line-numbers | grep -E "^\s*1\s+" | head -1)
if ! echo "$FIRST_RULE" | grep -q "ZALP_DPI"; then
    echo -e "${RED}✗ FAIL: После zalp doctor правила ZALP_DPI не на позиции 1${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: zalp doctor корректно восстанавливает правила${NC}"
exit 0