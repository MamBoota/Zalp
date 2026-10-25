#!/bin/bash
# Запуск всех тестов Zalp

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         Zalp Test Suite v1.0                         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Тесты должны запускаться от root (sudo)${NC}"
    exit 1
fi

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)
    
    TOTAL=$((TOTAL + 1))
    echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}Запуск теста: $test_name${NC}"
    
    if bash "$test_file"; then
        PASSED=$((PASSED + 1))
    else
        local exit_code=$?
        if [ $exit_code -eq 77 ]; then
            SKIPPED=$((SKIPPED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    fi
    echo ""
}

# Запускаем все тесты
for test_file in "$SCRIPT_DIR"/test_*.sh; do
    if [ -f "$test_file" ]; then
        run_test "$test_file"
    fi
done

# Итоги
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    ИТОГИ ТЕСТОВ                      ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC} Всего тестов:  ${YELLOW}$TOTAL${NC}"
echo -e "${CYAN}║${NC} Пройдено:      ${GREEN}$PASSED${NC}"
echo -e "${CYAN}║${NC} Пропущено:     ${YELLOW}$SKIPPED${NC}"
echo -e "${CYAN}║${NC} Провалено:     ${RED}$FAILED${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}✗ Некоторые тесты провалены!${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Все тесты успешно пройдены!${NC}"
    exit 0
fi