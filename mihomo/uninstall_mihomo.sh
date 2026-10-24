#!/bin/bash
echo "🗑️ Начинаем полное удаление Mihomo и всех связанных настроек..."

# 1. Остановка и отключение сервиса
echo "[1/6] Остановка и отключение сервиса mihomo..."
sudo systemctl stop mihomo 2>/dev/null
sudo systemctl disable mihomo 2>/dev/null

# 2. Удаление systemd юнита и сброс счетчиков ошибок
echo "[2/6] Удаление файла сервиса..."
sudo rm -f /etc/systemd/system/mihomo.service
sudo systemctl daemon-reload
sudo systemctl reset-failed 2>/dev/null

# 3. Удаление бинарных файлов и команд управления
echo "[3/6] Удаление исполняемых файлов и команд управления..."
sudo rm -f /usr/local/bin/mihomo
sudo rm -f /usr/local/bin/mihomo-start
sudo rm -f /usr/local/bin/mihomo-stop
sudo rm -f /usr/local/bin/mihomo-restart
sudo rm -f /usr/local/bin/mihomo-test

# 4. Удаление конфигураций и рабочих директорий
echo "[4/6] Удаление конфигураций и временных файлов..."
sudo rm -rf /etc/mihomo
sudo rm -rf /opt/mihomo

# 5. Очистка cron (удаление watchdog задачи)
echo "[5/6] Удаление задачи watchdog из cron..."
crontab -l 2>/dev/null | grep -v "mihomo-watchdog" | grep -v "systemctl restart mihomo" | crontab -

# 6. Очистка остатков правил фаервола от наших экспериментов (nftables и iptables)
echo "[6/6] Очистка остатков сетевых правил..."
sudo nft delete table inet mihomo_zalp 2>/dev/null
sudo iptables -t mangle -F MIHOMO_TPROXY 2>/dev/null
sudo iptables -t mangle -X MIHOMO_TPROXY 2>/dev/null
sudo iptables -t mangle -D PREROUTING -j MIHOMO_TPROXY 2>/dev/null

echo ""
echo "✅ Готово! Mihomo, все его конфиги, команды управления и следы в фаерволе полностью удалены."
echo "Система возвращена в чистое состояние."
