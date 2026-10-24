#!/bin/bash
set -e
echo "=========================================================="
echo "🚀 УСТАНОВКА, НАСТРОЙКА И СОЗДАНИЕ КОМАНД УПРАВЛЕНИЯ MIHOMO"
echo "=========================================================="

# 1. ПОЛНАЯ ОЧИСТКА
echo "[1/7] Очистка предыдущих установок..."
systemctl stop mihomo 2>/dev/null || true
systemctl disable mihomo 2>/dev/null || true
rm -f /etc/systemd/system/mihomo.service
rm -rf /opt/mihomo /etc/mihomo
rm -f /usr/local/bin/mihomo
rm -f /usr/local/bin/mihomo-start /usr/local/bin/mihomo-stop /usr/local/bin/mihomo-restart /usr/local/bin/mihomo-test
systemctl daemon-reload

# 2. УСТАНОВКА
echo "[2/7] Загрузка и установка Mihomo..."
mkdir -p /opt/mihomo /etc/mihomo/providers
cd /opt/mihomo
wget -q -O mihomo.gz https://github.com/MetaCubeX/mihomo/releases/download/v1.19.33/mihomo-linux-amd64-compatible-v1.19.33.gz
gzip -d mihomo.gz
mv mihomo /usr/local/bin/mihomo
chmod +x /usr/local/bin/mihomo

# 3. КОНФИГУРАЦИЯ (Максимальная стабильность)
echo "[3/7] Создание конфигурации..."

# 🟢 ЗАПРОС URL ПОДПИСКИ У ПОЛЬЗОВАТЕЛЯ
echo "----------------------------------------------------------"
echo "🔗 Введите URL вашей подписки от поставщика VPN-услуг."
echo "   (Например: https://example.com/sub/abcdef)"
echo "----------------------------------------------------------"
read -p "👉 URL подписки: " SUBSCRIPTION_URL

# Проверка на пустоту
while [ -z "$SUBSCRIPTION_URL" ]; do
    echo "❌ URL не может быть пустым! Введите ссылку заново."
    read -p "👉 URL подписки: " SUBSCRIPTION_URL
done

echo "✅ URL принят: $SUBSCRIPTION_URL"
echo "----------------------------------------------------------"

# ⚠️ ВАЖНО: убраны кавычки у 'EOF' -> EOF, чтобы подставилась переменная $SUBSCRIPTION_URL
cat << EOF > /etc/mihomo/config.yaml
mixed-port: 7890
allow-lan: true
bind-address: "*"
mode: rule
log-level: warning
ipv6: false
unified-delay: true
tcp-concurrent: true
find-process-mode: off
external-controller: 127.0.0.1:9090
tun:
  enable: true
  stack: system
  auto-route: false
  auto-detect-interface: true
  dns-hijack:
  - any:53
sniffer:
  enable: true
  force-dns-mapping: true
  parse-pure-ip: true
  override-destination: true
  sniff:
    TLS:
      ports: [443, 8443]
    HTTP:
      ports: [80, 8080-8880]
dns:
  enable: true
  listen: 0.0.0.0:1053
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
  - '*.lan'
  - '*.local'
  - 'msftconnecttest.com'
  default-nameserver:
  - 1.1.1.1
  - 8.8.8.8
  nameserver:
  - https://dns.cloudflare.com/dns-query
  - https://dns.google/dns-query
proxy-providers:
  my-subscription:
    type: http
    url: "$SUBSCRIPTION_URL"
    interval: 3600
    path: ./providers/my-sub.yaml
    health-check:
      enable: true
      interval: 300
      url: http://www.gstatic.com/generate_204
      timeout: 5000
proxy-groups:
  - name: "AUTO-FASTEST"
    type: url-test
    use:
      - my-subscription
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    lazy: true
rules:
  - MATCH,AUTO-FASTEST
EOF

# 4. SYSTEMD СЕРВИС
echo "[4/7] Регистрация сервиса с автоперезапуском..."
cat << 'EOF' > /etc/systemd/system/mihomo.service
[Unit]
Description=Mihomo Proxy Service
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/etc/mihomo
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
Restart=always
RestartSec=3
LimitNOFILE=65535
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable mihomo
systemctl restart mihomo
sleep 4

# 5. СОЗДАНИЕ КОМАНД УПРАВЛЕНИЯ
echo "[5/7] Создание команд управления (mihomo-start/stop/restart/test)..."

# mihomo-start
cat << 'EOF' > /usr/local/bin/mihomo-start
#!/bin/bash
echo "▶️ Запуск Mihomo..."
systemctl start mihomo
sleep 2
if systemctl is-active --quiet mihomo; then
echo "✅ Mihomo успешно запущен."
else
echo "❌ Ошибка запуска. Проверьте: journalctl -u mihomo -n 10"
fi
EOF
chmod +x /usr/local/bin/mihomo-start

# mihomo-stop
cat << 'EOF' > /usr/local/bin/mihomo-stop
#!/bin/bash
echo "⏹️ Остановка Mihomo..."
systemctl stop mihomo
if ! systemctl is-active --quiet mihomo; then
echo "✅ Mihomo успешно остановлен."
else
echo "❌ Не удалось остановить сервис."
fi
EOF
chmod +x /usr/local/bin/mihomo-stop

# mihomo-restart
cat << 'EOF' > /usr/local/bin/mihomo-restart
#!/bin/bash
echo "🔄 Перезапуск Mihomo..."
systemctl restart mihomo
sleep 3
if systemctl is-active --quiet mihomo; then
echo "✅ Mihomo успешно перезапущен."
else
echo "❌ Ошибка перезапуска."
fi
EOF
chmod +x /usr/local/bin/mihomo-restart

# mihomo-test (Расширенная диагностика)
cat << 'EOF' > /usr/local/bin/mihomo-test
#!/bin/bash
echo "=========================================================="
echo "🔍 ДИАГНОСТИКА MIHOMO"
echo "=========================================================="
# 1. Статус сервиса
if systemctl is-active --quiet mihomo; then
echo "✅ Статус сервиса: ACTIVE (Работает)"
else
echo "❌ Статус сервиса: INACTIVE (Не работает)"
exit 1
fi
# 2. Текущий активный узел
NODE=$(curl -s http://127.0.0.1:9090/proxies/AUTO-FASTEST 2>/dev/null | grep -o '"now":"[^"]*"' | cut -d'"' -f4)
if [ -n "$NODE" ]; then
echo "✅ Активный узел: $NODE"
else
echo "⚠️ Не удалось определить активный узел (возможно, подписка еще грузится)"
fi
# 3. Тест HTTP/HTTPS
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -x http://127.0.0.1:7890 http://www.gstatic.com/generate_204 -m 5)
HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -x http://127.0.0.1:7890 https://www.google.com -m 5)
if [ "$HTTP_CODE" == "204" ] || [ "$HTTP_CODE" == "200" ]; then
echo "✅ HTTP прокси: ОК (Код: $HTTP_CODE)"
else
echo "❌ HTTP прокси: СБОЙ (Код: $HTTP_CODE)"
fi
if [ "$HTTPS_CODE" == "200" ]; then
echo "✅ HTTPS прокси: ОК (Код: $HTTPS_CODE)"
else
echo "❌ HTTPS прокси: СБОЙ (Код: $HTTPS_CODE)"
fi
# 4. Внешний IP
EXT_IP=$(curl -s -x http://127.0.0.1:7890 https://api.ipify.org -m 5)
if [[ "$EXT_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
echo "✅ Внешний IP через прокси: $EXT_IP"
else
echo "❌ Не удалось определить внешний IP (Получено: $EXT_IP)"
fi
echo "=========================================================="
EOF
chmod +x /usr/local/bin/mihomo-test

# 6. ПЕРВИЧНЫЙ ТЕСТ ПОСЛЕ УСТАНОВКИ
echo "[6/7] Запуск первичного тестирования..."
mihomo-test

# 7. WATCHDOG
echo "[7/7] Установка watchdog (проверка каждые 5 минут)..."
(crontab -l 2>/dev/null | grep -v "mihomo-watchdog") | crontab -
echo "*/5 * * * * curl -s -m 5 -x http://127.0.0.1:7890 http://www.gstatic.com/generate_204 >/dev/null || systemctl restart mihomo" | crontab -

echo "✅ Установка и настройка полностью завершены."
echo "💡 Используй команды: mihomo-start, mihomo-stop, mihomo-restart, mihomo-test"
echo "=========================================================="