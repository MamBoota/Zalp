#!/bin/bash
# Тест: Проверка, что zalp doctor восстанавливает правила после их удаления
# Сценарий: Намеренно ломаем правила, запускаем doctor, проверяем восстановление

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${YELLOW}[TEST] Проверка восстановления через zalp doctor...${NC}"

# Определяем ожидаемую позицию ZALP_DPI
EXPECTED_POS=1
if iptables -t mangle -L PREROUTING -n | grep -q "TV_VPN_FIX"; then
    EXPECTED_POS=2
    echo -e "${CYAN}  Обнаружен TV_VPN_FIX, ожидаемая позиция ZALP_DPI: 2${NC}"
else
    echo -e "${CYAN}  TV_VPN_FIX не обнаружен, ожидаемая позиция ZALP_DPI: 1${NC}"
fi

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

# Проверяем восстановление TV_VPN_FIX (если он есть)
if iptables -t mangle -L PREROUTING -n | grep -q "TV_VPN_FIX"; then
    tv_pos=$(iptables -t mangle -L PREROUTING -n --line-numbers | grep "TV_VPN_FIX" | awk '{print $1}')
    [ "$tv_pos" != "1" ] && { echo "FAIL: TV_VPN_FIX не на позиции 1 после doctor"; exit 1; }
    echo "✓ TV_VPN_FIX восстановлен на позиции 1"
fi

# Проверяем, что ZALP_DPI на правильной позиции
ACTUAL_POS=$(iptables -t mangle -L PREROUTING -n --line-numbers | grep "ZALP_DPI" | awk '{print $1}')
if [ "$ACTUAL_POS" != "$EXPECTED_POS" ]; then
    echo -e "${RED}✗ FAIL: После zalp doctor правила ZALP_DPI на позиции $ACTUAL_POS (ожидалось: $EXPECTED_POS)${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: zalp doctor корректно восстанавливает правила (позиция $EXPECTED_POS)${NC}"
exit 0