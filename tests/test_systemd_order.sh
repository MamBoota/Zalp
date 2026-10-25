#!/bin/bash
# Тест: Проверка, что Mihomo настроен запускаться после nfqws
# Ожидается: В mihomo.service.d/zalp-override.conf есть After=nfqws.service

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[TEST] Проверка порядка запуска сервисов systemd...${NC}"

# Проверяем, что Mihomo установлен
if ! systemctl list-unit-files | grep -q "mihomo.service"; then
    echo -e "${YELLOW}⚠ SKIP: Mihomo не установлен, тест пропущен${NC}"
    exit 0
fi

# Проверяем, что существует drop-in override
OVERRIDE_FILE="/etc/systemd/system/mihomo.service.d/zalp-override.conf"
if [ ! -f "$OVERRIDE_FILE" ]; then
    echo -e "${RED}✗ FAIL: Файл $OVERRIDE_FILE не существует${NC}"
    exit 1
fi

# Проверяем, что в override есть After=nfqws.service
if ! grep -q "After=.*nfqws.service" "$OVERRIDE_FILE"; then
    echo -e "${RED}✗ FAIL: В override отсутствует After=nfqws.service${NC}"
    exit 1
fi

# Проверяем, что в override есть ExecStartPost с zalp doctor
if ! grep -q "ExecStartPost=.*zalp doctor" "$OVERRIDE_FILE"; then
    echo -e "${RED}✗ FAIL: В override отсутствует ExecStartPost с zalp doctor${NC}"
    exit 1
fi

# Проверяем порядок запуска через systemd-analyze
echo -e "${CYAN}  Проверка порядка запуска через systemd-analyze...${NC}"
if command -v systemd-analyze >/dev/null 2>&1; then
    ORDER=$(systemd-analyze critical-chain mihomo.service 2>/dev/null || echo "")
    if echo "$ORDER" | grep -q "nfqws.service"; then
        echo -e "${GREEN}  ✓ systemd-analyze подтверждает: nfqws запускается до mihomo${NC}"
    else
        echo -e "${YELLOW}  ⚠ systemd-analyze не показывает явной зависимости (но override корректен)${NC}"
    fi
fi

echo -e "${GREEN}✓ PASS: Mihomo настроен запускаться после nfqws${NC}"
exit 0