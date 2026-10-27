#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║           Zalp Installer v5.3 (Unified)              ║
# ║     DPI Bypass + Mihomo + TV Fix + Doctor            ║
# ╚══════════════════════════════════════════════════════╝
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
LOG=/var/log/zalp-install.log

# Определяем SCRIPT_DIR сразу, чтобы он был доступен везде
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Функция валидации ввода Y/N
validate_yn_input() {
    local prompt="$1"
    local result_var="$2"
    
    while true; do
        read -p "$prompt" answer
        if [[ "$answer" =~ ^[YyNn]$ ]]; then
            eval "$result_var='$answer'"
            return 0
        else
            echo -e "${RED}  ✗ Ошибка: введите только Y или N${NC}"
        fi
    done
}

: > "$LOG"
exec > >(tee -a "$LOG") 2>&1
trap 'echo -e "${RED}✗ Скрипт упал на строке $LINENO! Лог: $LOG${NC}"' ERR

echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Zalp Installer v5.3 (Unified)              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Запускать только через sudo${NC}"
    exit 1
fi

# 0. Проверка на существующую установку
echo -e "${YELLOW}[0/6] Проверка существующей установки...${NC}"
if [ -d /opt/zalp ] && [ -x /opt/zalp/binaries/my/nfqws ]; then
    echo -e "${YELLOW}  ⚠️  Zalp уже установлен.${NC}"
    echo -e "${YELLOW}  Для переустановки используйте: ${CYAN}sudo ./restore.sh${NC}"
    exit 0
fi

# 1. Зависимости
echo -e "${YELLOW}[1/6] Установка зависимостей...${NC}"
apt update -qq
apt install -y -qq git build-essential make gcc zlib1g-dev libcap-dev \
    libnetfilter-queue-dev libmnl-dev libsystemd-dev \
    netfilter-persistent iptables curl wget openssl > /dev/null 2>&1
echo -e "${GREEN}  ✓ Зависимости установлены${NC}"

# 2. Движок Zalp
echo -e "${YELLOW}[2/6] Установка и компиляция движка Zalp...${NC}"
if [ ! -d /opt/zalp ]; then
    git clone https://github.com/bol-van/zapret.git /opt/zalp
fi
cd /opt/zalp
if [ ! -x ./binaries/my/nfqws ] || [ ! -x ./binaries/my/tpws ]; then
    echo "  Компиляция движка из исходников (1-3 минуты)..."
    make systemd > /tmp/zalp-build.log 2>&1 || {
        echo -e "${RED}✗ Ошибка сборки движка. Проверьте /tmp/zalp-build.log${NC}"
        exit 1
    }
fi
./install_bin.sh || true
echo -e "${GREEN}  ✓ Движок собран и установлен${NC}"

# 3. Конфигурации доменов и TV MACs
echo -e "${YELLOW}[3/6] Настройка конфигураций (Домены + TV MACs)...${NC}"

if [ -f "$SCRIPT_DIR/tv_macs.conf" ]; then
    cp -f "$SCRIPT_DIR/tv_macs.conf" /opt/zalp/tv_macs.conf
    echo -e "${GREEN}  ✓ Конфиг TV MACs скопирован из репозитория${NC}"
else
    cat > /opt/zalp/tv_macs.conf << 'EOF'
SERVER_IP="auto"

# 74:E6:B8:06:CD:8A # LG WebOS 3-й этаж
# 04:B9:E3:4A:3C:EC # Samsung 2-й этаж
# 04:B9:E3:4A:3C:EC # Samsung 4-й этаж
EOF
    echo -e "${YELLOW}  ⚠️  Создан шаблон /opt/zalp/tv_macs.conf. Заполните его MAC-адресами.${NC}"
fi

cat > /opt/zalp/domains.txt << 'EOF'
youtube.com
youtubei.googleapis.com
googlevideo.com
ytimg.com
ggpht.com
googleapis.com
google.com
gstatic.com
youtu.be
youtube-nocookie.com
googleusercontent.com
yt3.ggpht.com
i.ytimg.com
s.ytimg.com
jnn-pa.googleapis.com
instagram.com
cdninstagram.com
i.instagram.com
threads.net
www.threads.net
graph.instagram.com
facebook.com
www.facebook.com
EOF

cat > /opt/zalp/domains-exclude.txt << 'EOF'
itstorm.ru
prof.itstorm.ru
1c.ru
v8.1c.ru
vokino.tv
EOF
echo -e "${GREEN}  ✓ Конфиги доменов и TV MACs применены${NC}"

# 4. Systemd-сервис nfqws
echo -e "${YELLOW}[4/6] Создание systemd-сервиса nfqws...${NC}"
cat > /etc/systemd/system/nfqws.service << 'EOF'
[Unit]
Description=Zalp DPI bypass (nfqws)
After=network.target

[Service]
Type=simple
ExecStartPre=/sbin/sysctl -w net.ipv4.ip_forward=1
ExecStart=/opt/zalp/binaries/my/nfqws --qnum=1 --filter-tcp=80,443 --filter-udp=443 --hostlist=/opt/zalp/domains.txt --hostlist-exclude=/opt/zalp/domains-exclude.txt --dpi-desync=fakedsplit --dpi-desync-split-pos=1 --dpi-desync-autottl --dpi-desync-fooling=badseq --dpi-desync-repeats=2
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
echo -e "${GREEN}  ✓ Сервис nfqws создан${NC}"

# 5. Опциональные модули (Mihomo и TV Fix)
echo -e "${YELLOW}[5/6] Настройка дополнительных модулей...${NC}"

validate_yn_input "  Установить модуль прозрачного прокси Mihomo? (Y/N): " INSTALL_MIHOMO

if [[ "$INSTALL_MIHOMO" =~ ^[Yy]$ ]]; then
    echo "  Установка Mihomo..."
    if [ -f "$SCRIPT_DIR/mihomo/install_mihomo.sh" ]; then
        chmod +x "$SCRIPT_DIR/mihomo/install_mihomo.sh"
        if "$SCRIPT_DIR/mihomo/install_mihomo.sh"; then
            echo -e "${GREEN}  ✓ Mihomo успешно установлен.${NC}"
        else
            echo -e "${YELLOW}  ⚠️  Установка Mihomo прервана или завершилась с ошибкой.${NC}"
        fi
    else
        echo -e "${RED}  ✗ Скрипт mihomo/install_mihomo.sh не найден.${NC}"
    fi
fi

validate_yn_input "  Установить TV Fix VPN (прозрачный VPN для Smart TV)? (Y/N): " INSTALL_TVFIX

if [[ "$INSTALL_TVFIX" =~ ^[Yy]$ ]]; then
    echo "  Установка TV Fix VPN..."
    if [ -f "$SCRIPT_DIR/TV_FIX_VPN/install-tv-fix-vpn.sh" ]; then
        chmod +x "$SCRIPT_DIR/TV_FIX_VPN/install-tv-fix-vpn.sh"
        if "$SCRIPT_DIR/TV_FIX_VPN/install-tv-fix-vpn.sh"; then
            echo -e "${GREEN}  ✓ TV Fix VPN успешно установлен.${NC}"
        else
            echo -e "${YELLOW}  ⚠️  Установка TV Fix прервана или завершилась с ошибкой.${NC}"
        fi
    else
        echo -e "${RED}  ✗ Скрипт TV_FIX_VPN/install-tv-fix-vpn.sh не найден.${NC}"
    fi
fi

echo -e "${GREEN}  ✓ Модули настроены${NC}"

echo -e "${GREEN}  ✓ Модули настроены${NC}"

# 6. Скрипты управления и консоль
echo -e "${YELLOW}[6/6] Установка единой консоли управления и автозапуска...${NC}"

if [ -f "$SCRIPT_DIR/zalp-console.sh" ]; then
    cp "$SCRIPT_DIR/zalp-console.sh" /usr/local/bin/zalp
    chmod +x /usr/local/bin/zalp
fi

for cmd in start stop restart status check doctor restore test mihomo tvfix; do
    echo -e "#!/bin/bash\nexec zalp \$@" > "/usr/local/bin/zalp-$cmd"
    chmod +x "/usr/local/bin/zalp-$cmd"
done

echo "5.3" > /opt/zalp/VERSION

systemctl daemon-reload
systemctl enable -q nfqws
(crontab -l 2>/dev/null | grep -v "zalp-doctor"; echo "*/5 * * * * /usr/local/bin/zalp doctor >/dev/null 2>&1") | crontab -

grep -qxF 'net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
grep -qxF 'net.ipv6.conf.all.forwarding=1' /etc/sysctl.conf || echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p > /dev/null 2>&1

systemctl start nfqws
/usr/local/bin/zalp doctor || true

echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Zalp v5.3 успешно установлен!                     ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║  Введите ${YELLOW}sudo zalp${CYAN} для открытия панели управления.      ║${NC}"
echo -e "${CYAN}║  Автозапуск: systemd + cron (каждые 5 мин)           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"