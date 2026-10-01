#!/bin/bash

# Zalp Installer Script
# Устанавливает Zalp — систему обхода DPI + прокси для Telegram/Discord

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Zalp Installer v1.0               ║${NC}"
echo -e "${GREEN}║   DPI Bypass + Proxy System            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Этот скрипт должен запускаться с правами root (sudo)${NC}"
    exit 1
fi

# Проверка Ubuntu/Debian
if [ ! -f /etc/debian_version ]; then
    echo -e "${RED}✗ Zalp поддерживает только Ubuntu/Debian системы${NC}"
    exit 1
fi

echo -e "${YELLOW}→ Обновление системы...${NC}"
apt update && apt upgrade -y

echo -e "${YELLOW}→ Установка зависимостей...${NC}"
apt install -y git build-essential netfilter-persistent iptables curl wget

# Создание директорий Zalp
echo -e "${YELLOW}→ Создание структуры Zalp...${NC}"
mkdir -p /opt/zalp
mkdir -p /opt/zalp/configs
mkdir -p /opt/zalp/scripts
mkdir -p /opt/zalp/systemd
mkdir -p /opt/zalp/docs

# Клонирование оригинального zapret
echo -e "${YELLOW}→ Установка базового Zalp...${NC}"
cd /opt
if [ -d "zapret" ]; then
    echo -e "${YELLOW}  Zalp уже установлен, пропускаем клонирование...${NC}"
else
    git clone https://github.com/bol-van/zapret.git
fi
cd zapret
./install_bin.sh

# Установка 3proxy
echo -e "${YELLOW}→ Установка 3proxy для Telegram и Discord...${NC}"
apt install -y 3proxy

# Применение конфигураций
echo -e "${YELLOW}→ Применение конфигураций Zalp...${NC}"

# Создание domains.txt
cat > /opt/zalp/configs/domains.txt << 'EOF'
youtube.com
googlevideo.com
ytimg.com
googleapis.com
instagram.com
threads.net
facebook.com
fbcdn.net
cdninstagram.com
twitter.com
twimg.com
x.com
discord.com
discordapp.com
discord.gg
discord.media
EOF

# Создание domains-exclude.txt
cat > /opt/zalp/configs/domains-exclude.txt << 'EOF'
1c.ru
1c.com
vokino.ru
vokino.tv
sberbank.ru
gosuslugi.ru
yandex.ru
mail.ru
vk.com
ok.ru
EOF

# Создание nfqws.conf
cat > /opt/zalp/configs/nfqws.conf << 'EOF'
# Zalp NFQWS Configuration
# Оптимизирован для стриминга видео (4K, Shorts, Reels)

nfqws --dpi-desync=fake,split --dpi-desync-split-pos=1 \
      --dpi-desync-split-http-req=method \
      --dpi-desync-split-tls=sniext \
      --dpi-desync-fooling=md5sig \
      --dpi-desync-repeats=2 \
      --dpi-desync-ttl=6
EOF

# Создание zalp-doctor.sh
cat > /opt/zalp/scripts/zalp-doctor.sh << 'EOF'
#!/bin/bash

# Zalp Doctor - система самолечения
# Проверяет работу Zalp каждые 5 минут

LOG="/var/log/zalp-doctor.log"
timestamp=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$timestamp] Запуск проверки Zalp..." >> $LOG

# Проверка наличия интернета
if ! ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then
    echo "[$timestamp] ✗ Нет интернета!" >> $LOG
    exit 1
fi

# Проверка правил iptables
if ! iptables -t mangle -L | grep -q "NFQUEUE"; then
    echo "[$timestamp] ✗ Правила NFQUEUE отсутствуют, восстановление..." >> $LOG
    /opt/zapret/zapret-restart
fi

# Проверка 3proxy
if ! systemctl is-active --quiet 3proxy; then
    echo "[$timestamp] ✗ 3proxy не запущен, перезапуск..." >> $LOG
    systemctl restart 3proxy
fi

echo "[$timestamp] ✓ Zalp работает корректно" >> $LOG
EOF

chmod +x /opt/zalp/scripts/zalp-doctor.sh

# Создание systemd сервисов
cat > /opt/zalp/systemd/zalp-doctor.service << 'EOF'
[Unit]
Description=Zalp Doctor - Health Check Service
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/zalp/scripts/zalp-doctor.sh
User=root
EOF

cat > /opt/zalp/systemd/zalp-doctor.timer << 'EOF'
[Unit]
Description=Run Zalp Doctor every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

# Активация systemd сервисов
echo -e "${YELLOW}→ Настройка автозапуска сервисов...${NC}"
cp /opt/zalp/systemd/zalp-doctor.service /etc/systemd/system/
cp /opt/zalp/systemd/zalp-doctor.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable zalp-doctor.timer
systemctl start zalp-doctor.timer

# Запуск Zalp Doctor первый раз
echo -e "${YELLOW}→ Первый запуск Zalp Doctor...${NC}"
/opt/zalp/scripts/zalp-doctor.sh

# Создание restore.sh
cat > /opt/zalp/restore.sh << 'EOF'
#!/bin/bash

# Zalp Restore Script
# Восстанавливает полную конфигурацию системы

echo "Восстановление Zalp..."

# Применение конфигураций
cp /opt/zalp/configs/domains.txt /opt/zapret/config/
cp /opt/zalp/configs/domains-exclude.txt /opt/zapret/config/

# Перезапуск сервисов
systemctl restart 3proxy
/opt/zapret/zapret-restart

echo "Zalp восстановлен!"
EOF

chmod +x /opt/zalp/restore.sh

# Финальная настройка
echo -e "${YELLOW}→ Финальная настройка...${NC}"

# Включение IP forwarding
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Zalp успешно установлен!                ║${NC}"
echo -e "${GREEN}╠════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Следующие шаги:                           ║${NC}"
echo -e "${GREEN}║                                            ║${NC}"
echo -e "${GREEN}║  1. Запусти: sudo /opt/zalp/restore.sh     ║${NC}"
echo -e "${GREEN}║  2. Перезапусти: sudo zapret-restart       ║${NC}"
echo -e "${GREEN}║  3. Настрой прокси (см. docs/SETUP.md)     ║${NC}"
echo -e "${GREEN}║                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""