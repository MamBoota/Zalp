#!/bin/bash

# ╔══════════════════════════════════════════════════════╗
# ║           Zalp Installer v4.0 (Stable)               ║
# ║     DPI Bypass + Doctor + Autostart                  ║
# ╚══════════════════════════════════════════════════════╝

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

LOG=/var/log/zalp-install.log
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1
trap 'echo -e "${RED}✗ Скрипт упал на строке $LINENO! Лог: $LOG${NC}"' ERR

echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Zalp Installer v4.0 (Stable)               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Запускать только через sudo${NC}"
    exit 1
fi

# ── Функция проверки наличия продукта ──
# Ищет ВСЕ следы установки, а не только каталог
is_installed() {
    local traces=0
    
    # 1. Каталог движка
    [ -d /opt/zalp ] && ((traces++))
    
    # 2. Рабочий бинарник nfqws
    [ -x /opt/zalp/binaries/my/nfqws ] && ((traces++))
    
    # 3. Системный сервис
    [ -f /etc/systemd/system/nfqws.service ] && ((traces++))
    
    # 4. Команды управления zalp-*
    [ -x /usr/local/bin/zalp-start ] && ((traces++))
    [ -x /usr/local/bin/zalp-doctor ] && ((traces++))
    
    # 5. Файлы конфигурации доменов
    [ -f /opt/zalp/domains.txt ] && ((traces++))
    
    # 6. Лог доктора (признак работы)
    [ -f /var/log/zalp-doctor.log ] && ((traces++))
    
    # Если нашли 4+ следов — считаем установленным
    [ $traces -ge 4 ]
}

# ── 0. Проверка на существующую установку ──
echo -e "${YELLOW}[0/?] Проверка существующей установки...${NC}"
if is_installed; then
    echo -e "${YELLOW}  ⚠️  Zalp уже установлен в системе.${NC}"
    echo -e "${YELLOW}  Чтобы переустановить — сначала запусти ${CYAN}restore.sh${NC}"
    echo -e "${YELLOW}  (он полностью очистит систему и запустит свежую установку)${NC}"
    exit 0
fi
echo -e "${GREEN}  ✓ Чистая система, начинаем установку${NC}"

# ── 1. Зависимости ──
echo -e "${YELLOW}[1/10] Установка зависимостей...${NC}"
apt update -qq
apt install -y -qq git build-essential make gcc zlib1g-dev libcap-dev \
    libnetfilter-queue-dev libmnl-dev libsystemd-dev \
    netfilter-persistent iptables curl wget openssl > /dev/null 2>&1
echo -e "${GREEN}  ✓ Зависимости установлены${NC}"

# ── 2. Движок Zalp ──
echo -e "${YELLOW}[2/10] Установка движка Zalp...${NC}"
if [ ! -d /opt/zalp ]; then
    git clone https://github.com/bol-van/zapret.git /opt/zalp
fi
cd /opt/zalp

if [ ! -x ./binaries/my/nfqws ] || [ ! -x ./binaries/my/tpws ]; then
    echo "  Компиляция движка из исходников (1-3 минуты)..."
    if ! make systemd > /tmp/zalp-build.log 2>&1; then
        echo -e "${RED}✗ Ошибка сборки движка:${NC}"
        tail -30 /tmp/zalp-build.log
        exit 1
    fi
fi

./install_bin.sh || true
if [ ! -x ./binaries/my/nfqws ]; then
    mkdir -p binaries/my
    for b in nfqws tpws ip2net mdig; do
        f=$(find . -maxdepth 2 -type f -name "$b" -perm -111 -not -path "./binaries/*" | head -1)
        [ -n "$f" ] && cp -f "$f" binaries/my/
    done
    ./install_bin.sh || true
fi
echo -e "${GREEN}  ✓ Движок собран${NC}"

# ── 3. Конфигурации доменов ──
echo -e "${YELLOW}[3/10] Применение конфигураций доменов...${NC}"

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
b.i.instagram.com
scontent.cdninstagram.com
static.cdninstagram.com
lookaside.fbsbx.com
facebook.com
www.facebook.com
api.instagram.com
video.cdninstagram.com
scontent-*.cdninstagram.com
*.fbcdn.net
*.fbsbx.com
edge-star-mini-shv-*.fbcdn.net
*.instagram.com
EOF

cat > /opt/zalp/domains-exclude.txt << 'EOF'
itstorm.ru
prof.itstorm.ru
1c.ru
v8.1c.ru
vokino.tv
EOF
echo -e "${GREEN}  ✓ Конфиги доменов применены${NC}"

# ── 4. Systemd-сервис nfqws ──
echo -e "${YELLOW}[4/10] Создание systemd-сервиса nfqws...${NC}"

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

# ── 5. Скрипты управления zalp-* ──
echo -e "${YELLOW}[5/10] Создание скриптов управления...${NC}"

# Автоопределение сетевого интерфейса
NET_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
[ -z "$NET_IFACE" ] && NET_IFACE="enp2s0"

cat > /usr/local/bin/zalp-start << EOF
#!/bin/bash
GREEN='\033[0;32m'
NC='\033[0m'
echo "🚀 Включаю Zalp DPI Bypass..."
sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
sudo sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null
sudo systemctl start nfqws
sudo iptables -t nat -F POSTROUTING
sudo iptables -F FORWARD
sudo iptables -t mangle -F PREROUTING
sudo ip6tables -t mangle -F PREROUTING
sudo ip6tables -F FORWARD
sudo iptables -t nat -A POSTROUTING -o $NET_IFACE -j MASQUERADE
sudo iptables -A FORWARD -j ACCEPT
sudo iptables -t mangle -A PREROUTING -p tcp -m multiport --dports 80,443 -j NFQUEUE --queue-num 1
sudo iptables -t mangle -A PREROUTING -p udp --dport 443 -j NFQUEUE --queue-num 1
sudo ip6tables -t mangle -A PREROUTING -p tcp -m multiport --dports 80,443 -j NFQUEUE --queue-num 1
sudo ip6tables -t mangle -A PREROUTING -p udp --dport 443 -j NFQUEUE --queue-num 1
sudo netfilter-persistent save > /dev/null
echo -e "\${GREEN}✅ Zalp активирован! (Интерфейс: $NET_IFACE).\${NC}"
EOF

cat > /usr/local/bin/zalp-stop << 'EOF'
#!/bin/bash
GREEN='\033[0;32m'
NC='\033[0m'
echo "⏹️ Выключаю Zalp DPI Bypass..."
sudo systemctl stop nfqws
sudo iptables -t mangle -F
sudo ip6tables -t mangle -F
sudo netfilter-persistent save > /dev/null
echo -e "${GREEN}✅ Zalp деактивирован!${NC}"
EOF

cat > /usr/local/bin/zalp-doctor << 'EOF'
#!/bin/bash
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'
LOG_FILE="/var/log/zalp-doctor.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Запуск Zalp Doctor" >> $LOG_FILE
EXIT_CODE=0

if ! systemctl is-active --quiet nfqws; then
    systemctl restart nfqws
fi

if [ "$(sysctl -n net.ipv4.ip_forward)" != "1" ]; then
    sysctl -w net.ipv4.ip_forward=1 > /dev/null
fi

NET_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
[ -z "$NET_IFACE" ] && NET_IFACE="enp2s0"

MASQ_COUNT=$(iptables -t nat -L POSTROUTING -n | grep -c "MASQUERADE")
FWD_ACCEPT_COUNT=$(iptables -L FORWARD -n | grep -c "ACCEPT")
if [ "$MASQ_COUNT" -gt 1 ]; then
    iptables -t nat -F POSTROUTING
    iptables -t nat -A POSTROUTING -o $NET_IFACE -j MASQUERADE
fi
if [ "$FWD_ACCEPT_COUNT" -gt 1 ]; then
    iptables -F FORWARD
    iptables -A FORWARD -j ACCEPT
fi

NFQ_COUNT=$(iptables -t mangle -L PREROUTING -n | grep -c "NFQUEUE")
if [ "$NFQ_COUNT" -lt 2 ]; then
    iptables -t mangle -A PREROUTING -p tcp -m multiport --dports 80,443 -j NFQUEUE --queue-num 1
    iptables -t mangle -A PREROUTING -p udp --dport 443 -j NFQUEUE --queue-num 1
fi

if ! curl -s -I -m 5 https://yandex.ru > /dev/null 2>&1 && ! curl -s -I -m 5 https://cloudflare.com > /dev/null 2>&1; then
    nmcli con up "netplan-$NET_IFACE" > /dev/null 2>&1 || true
    sleep 3
    if ! curl -s -I -m 5 https://yandex.ru > /dev/null 2>&1; then
        EXIT_CODE=1
    fi
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Сеть проверена.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}❌ Критические проблемы.${NC}" | tee -a $LOG_FILE
fi
exit $EXIT_CODE
EOF

cat > /usr/local/bin/zalp-restart << 'EOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
echo "🔄 Начинаю безопасный перезапуск..."
zalp-stop
sudo zalp-doctor
DOCTOR_EXIT_CODE=$?
if [ $DOCTOR_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}❌ Ошибка Доктора. Запуск отменен.${NC}"
    exit 1
fi
if ! curl -s -I -m 5 https://yandex.ru > /dev/null 2>&1; then
    echo -e "${RED}❌ Нет интернета. Запуск отменен.${NC}"
    exit 1
fi
zalp-start
echo -e "${GREEN}🎉 Перезапуск завершен!${NC}"
EOF

cat > /usr/local/bin/zalp-check << 'EOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
echo "========================================="
echo "  Zalp DPI Bypass - Диагностика"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
echo "🔧 1. Статус nfqws:"
if systemctl is-active --quiet nfqws; then
    echo -e "   ✅ ${GREEN}Активен${NC}"
else
    echo -e "   ❌ ${RED}Не активен${NC}"
fi
echo "🌐 2. IP Forwarding:"
if [ "$(sysctl -n net.ipv4.ip_forward)" = "1" ]; then
    echo -e "   ✅ ${GREEN}Включен${NC}"
else
    echo -e "   ❌ ${RED}Выключен${NC}"
fi
echo "🔥 3. Правила mangle:"
RULES=$(sudo iptables -t mangle -L PREROUTING -n | grep -c "NFQUEUE")
if [ "$RULES" -ge 2 ]; then
    echo -e "   ✅ ${GREEN}Найдено $RULES правил${NC}"
else
    echo -e "   ⚠️  ${YELLOW}Найдено $RULES правил${NC}"
fi
echo "🔄 4. NAT:"
NAT=$(sudo iptables -t nat -L POSTROUTING -n | grep -c "MASQUERADE")
if [ "$NAT" -gt 0 ]; then
    echo -e "   ✅ ${GREEN}Настроен${NC}"
else
    echo -e "   ❌ ${RED}Не настроен${NC}"
fi
echo "🌍 5. Интернет:"
if curl -s -I -m 3 https://google.com > /dev/null 2>&1; then
    echo -e "   ✅ ${GREEN}Работает${NC}"
else
    echo -e "   ❌ ${RED}Нет доступа${NC}"
fi
echo "========================================="
EOF

cat > /usr/local/bin/zalp-status << 'EOF'
#!/bin/bash
echo ""
echo "══════════ Zalp Status ══════════"
if sudo iptables -t mangle -L 2>/dev/null | grep -q "NFQUEUE"; then
    echo "  🟢 Обход DPI:    Активен"
else
    echo "  🔴 Обход DPI:    Не запущен"
fi
if systemctl is-active --quiet nfqws; then
    echo "  🟢 NFQWS:        Активен"
else
    echo "  🔴 NFQWS:        Не активен"
fi
if systemctl is-active --quiet zalp-doctor.timer 2>/dev/null || grep -q "zalp-doctor" /var/spool/cron/crontabs/root 2>/dev/null; then
    echo "  🟢 Доктор:       Активен"
else
    echo "  🔴 Доктор:       Не активен"
fi
echo ""
echo "  Лог доктора (последние 3):"
tail -3 /var/log/zalp-doctor.log 2>/dev/null | sed 's/^/    /'
echo "═════════════════════════════════"
EOF

cat > /usr/local/bin/zalp-restore << 'EOF'
#!/bin/bash
echo "Восстановление Zalp..."
zalp-restart
echo "✓ Zalp восстановлен!"
EOF

chmod +x /usr/local/bin/zalp-start /usr/local/bin/zalp-stop /usr/local/bin/zalp-restart
chmod +x /usr/local/bin/zalp-status /usr/local/bin/zalp-doctor /usr/local/bin/zalp-check
chmod +x /usr/local/bin/zalp-restore
echo -e "${GREEN}  ✓ Скрипты управления созданы${NC}"

# ── 6. Systemd + автозапуск ──
echo -e "${YELLOW}[6/10] Настройка автозапуска...${NC}"
systemctl daemon-reload
systemctl enable -q nfqws

# Cron для доктора (каждые 5 минут)
(crontab -l 2>/dev/null | grep -v "zalp-doctor"; echo "*/5 * * * * /usr/local/bin/zalp-doctor >/dev/null 2>&1") | crontab -
echo -e "${GREEN}  ✓ Автозапуск настроен (systemd + cron)${NC}"

# ── 7. IP Forwarding ──
echo -e "${YELLOW}[7/10] Настройка IP Forwarding...${NC}"
grep -qxF 'net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
grep -qxF 'net.ipv6.conf.all.forwarding=1' /etc/sysctl.conf || echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p > /dev/null 2>&1
echo -e "${GREEN}  ✓ IP Forwarding включен${NC}"

# ── 8. Запуск сервисов ──
echo -e "${YELLOW}[8/10] Запуск сервисов...${NC}"
systemctl start nfqws
/usr/local/bin/zalp-doctor || true
/usr/local/bin/zalp-start
echo -e "${GREEN}  ✓ Сервисы запущены${NC}"

# ── 9. Финальная проверка ──
echo -e "${YELLOW}[9/10] Финальная проверка...${NC}"
sleep 2
/usr/local/bin/zalp-check

# ── 10. Итог ──
echo -e "${YELLOW}[10/10] Готово!${NC}"
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Zalp v4.0 успешно установлен!                     ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║  Команды:                                            ║${NC}"
echo -e "${CYAN}║    zalp-start     — запустить                        ║${NC}"
echo -e "${CYAN}║    zalp-stop      — остановить                       ║${NC}"
echo -e "${CYAN}║    zalp-restart   — безопасный перезапуск            ║${NC}"
echo -e "${CYAN}║    zalp-status    — краткий статус                   ║${NC}"
echo -e "${CYAN}║    zalp-check     — полная диагностика               ║${NC}"
echo -e "${CYAN}║    zalp-doctor    — проверка и лечение               ║${NC}"
echo -e "${CYAN}║    zalp-restore   — восстановление                   ║${NC}"
echo -e "${CYAN}║                                                      ║${NC}"
echo -e "${CYAN}║  Автозапуск: systemd + cron (каждые 5 мин)           ║${NC}"
echo -e "${CYAN}║  Сетевой интерфейс: ${NET_IFACE}${NC}"
echo -e "${CYAN}║                                                      ║${NC}"
echo -e "${CYAN}║  Для переустановки: ./restore.sh                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""