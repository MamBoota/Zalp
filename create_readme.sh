#!/bin/bash
# ============================================================
# Zalp v5.2 — Генератор README.md
# Все строки выводятся через echo (без here-doc)
# ============================================================

set -e

cd "$(dirname "$0")" || exit 1

rm -f README.md

echo '# 🛡️ Zalp v5.2 — Умный обход DPI и управление сетью' >> README.md
echo '' >> README.md
echo '**Zalp** — это комплексная, модульная система обхода DPI-блокировок и управления сетевым трафиком на базе zapret, оптимизированная для домашнего сервера или роутера. В версии 5.2 система получила критические исправления изоляции TV Fix, централизованную конфигурацию MAC-адресов и улучшенную стабильность TPROXY.' >> README.md
echo '' >> README.md
echo '## ✨ Возможности' >> README.md
echo '' >> README.md
echo '- 🚀 **Обход DPI**: YouTube, Instagram, Facebook, Threads и другие сервисы.' >> README.md
echo '- 🛡️ **Стабильность iptables**: Изолированная цепочка `ZALP_DPI` предотвращает конфликты с Mihomo и TV Fix.' >> README.md
echo '- 🩺 **Zalp Doctor**: Автоматическое самолечение и мониторинг каждые 5 минут.' >> README.md
echo '- 🔄 **Горячая замена**: Переустановка и обновление без разрыва интернета.' >> README.md
echo '- 🎛️ **Единая консоль `zalp`**: Управление всеми модулями из одного меню.' >> README.md
echo '- 🌐 **Модуль Mihomo**: Прозрачный прокси (VLESS, Trojan, Shadowsocks и др.) с автоматической интеграцией.' >> README.md
echo '- 📺 **TV Fix VPN**: Прозрачный VPN для Smart TV (LG, Samsung) без настройки на самом телевизоре.' >> README.md
echo '- 🧪 **Test Suite**: Набор bash-тестов для проверки корректности работы модулей и правил.' >> README.md
echo '- 📦 **Самообновление**: Следит за релизами на GitHub и обновляется в один клик.' >> README.md
echo '' >> README.md

echo '## 📁 Структура проекта' >> README.md
echo '' >> README.md
echo '```text' >> README.md
echo 'Zalp/' >> README.md
echo '├── README.md             # Документация' >> README.md
echo '├── install.sh            # Универсальный установщик v5.2' >> README.md
echo '├── restore.sh            # Горячая замена и полный сброс' >> README.md
echo '├── uninstall.sh          # Полное удаление' >> README.md
echo '├── zalp-console.sh       # Единая панель управления (zalp)' >> README.md
echo '├── tv_macs.conf          # Центральная конфигурация MAC-адресов TV Fix' >> README.md
echo '├── create_readme.sh      # Генератор этого README' >> README.md
echo '├── tests/                # Набор автоматических тестов' >> README.md
echo '│   ├── run_all_tests.sh' >> README.md
echo '│   ├── test_iptables_priority.sh' >> README.md
echo '│   ├── test_systemd_order.sh' >> README.md
echo '│   ├── test_mihomo_conflict.sh' >> README.md
echo '│   ├── test_doctor_recovery.sh' >> README.md
echo '│   ├── test_edge_cases.sh' >> README.md
echo '│   └── test_tv_fix_dns.sh' >> README.md
echo '├── mihomo/               # Модуль прозрачного прокси' >> README.md
echo '│   ├── install_mihomo.sh' >> README.md
echo '│   ├── uninstall_mihomo.sh' >> README.md
echo '│   └── README.md' >> README.md
echo '└── TV_FIX_VPN/           # Модуль прозрачного VPN для Smart TV' >> README.md
echo '    ├── install-tv-fix-vpn.sh' >> README.md
echo '    ├── uninstall-tv-fix-vpn.sh' >> README.md
echo '    └── README.md' >> README.md
echo '```' >> README.md
echo '' >> README.md

echo '## 🚀 Быстрый старт' >> README.md
echo '' >> README.md
echo '### Установка' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'git clone https://github.com/MamBoota/Zalp.git' >> README.md
echo 'cd Zalp' >> README.md
echo 'sudo ./install.sh' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo 'Установщик предложит настроить базовый обход DPI, а также опционально установить **Mihomo** и **TV Fix**.' >> README.md
echo '' >> README.md
echo '### Единая консоль управления' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo zalp' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo '| Команда | Описание |' >> README.md
echo '| --- | --- |' >> README.md
echo '| `sudo zalp` | Интерактивная консоль управления |' >> README.md
echo '| `sudo zalp start` | Запустить обход DPI |' >> README.md
echo '| `sudo zalp stop` | Остановить обход DPI |' >> README.md
echo '| `sudo zalp restart` | Безопасный перезапуск |' >> README.md
echo '| `sudo zalp status` | Краткий статус всех модулей |' >> README.md
echo '| `sudo zalp doctor` | Самолечение и восстановление правил iptables |' >> README.md
echo '| `sudo zalp mihomo` | Меню управления прокси Mihomo |' >> README.md
echo '| `sudo zalp tvfix` | Меню управления прозрачным VPN для ТВ |' >> README.md
echo '| `sudo zalp test` | Запуск встроенного blockcheck.sh |' >> README.md
echo '| `sudo zalp restore` | Полная очистка и горячая переустановка |' >> README.md
echo '' >> README.md

echo '## 🌐 Модуль Mihomo (прозрачный прокси)' >> README.md
echo '' >> README.md
echo 'Mihomo — это прокси-ядро (Clash.Meta), которое позволяет использовать подписки VLESS/Trojan/Shadowsocks как прозрачный прокси.' >> README.md
echo '' >> README.md
echo '### Автоматическая интеграция с Zalp' >> README.md
echo '' >> README.md
echo '1. Запуск Mihomo гарантированно происходит **строго после** `nfqws` (Zalp).' >> README.md
echo '2. После старта Mihomo автоматически вызывается `zalp doctor`, чтобы восстановить приоритет правил `ZALP_DPI`.' >> README.md
echo '' >> README.md
echo '| Команда | Описание |' >> README.md
echo '| --- | --- |' >> README.md
echo '| `mihomo-start` | Запуск сервиса |' >> README.md
echo '| `mihomo-stop` | Остановка |' >> README.md
echo '| `mihomo-restart` | Перезапуск |' >> README.md
echo '| `mihomo-test` | Диагностика (статус, узел, HTTP/HTTPS, внешний IP) |' >> README.md
echo '' >> README.md

echo '## 📺 Модуль TV Fix VPN (прозрачный VPN для Smart TV)' >> README.md
echo '' >> README.md
echo 'TV Fix — это надстройка над Mihomo, которая перехватывает трафик Smart TV по MAC-адресу и прозрачно направляет его через VPN.' >> README.md
echo '' >> README.md
echo '### ⚙️ Конфигурация TV Fix (ВАЖНО)' >> README.md
echo '' >> README.md
echo 'Начиная с версии 5.2, MAC-адреса телевизоров вынесены в центральный файл `/opt/zalp/tv_macs.conf`:' >> README.md
echo '' >> README.md
echo '```text' >> README.md
echo 'SERVER_IP="192.168.10.100"  # IP сервера с Zalp (или "auto")' >> README.md
echo '74:E6:B8:06:CD:8A           # MAC-адрес первого телевизора' >> README.md
echo '04:B9:E3:4A:3C:EC           # MAC-адрес второго телевизора' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo '*После изменения файла выполните `sudo fix restart` для применения правил.*' >> README.md
echo '' >> README.md
echo '### Установка' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo ./TV_FIX_VPN/install-tv-fix-vpn.sh' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo '### 🛡 Как обеспечивается полная изоляция от Zalp' >> README.md
echo '' >> README.md
echo 'Архитектура гарантирует, что трафик ТВ и обычных устройств **никогда не пересекается**:' >> README.md
echo '' >> README.md
echo '1. **Приоритет правил:** `TV_VPN_FIX` закреплена на **позиции 1** в `PREROUTING`, а `ZALP_DPI` — на позиции 2.' >> README.md
echo '2. **Перехват DNS:** UDP-запросы на порт 53 от указанных MAC-адресов перенаправляются (DNAT) на внутренний DNS Mihomo (порт 1053).' >> README.md
echo '3. **Прозрачный прокси (TPROXY):** TCP-трафик помечается маркой `fwmark 0x1`. Скрипт автоматически настраивает `policy routing` (`ip rule` + `ip route table 100`), чтобы ядро доставляло трафик в Mihomo.' >> README.md
echo '4. **Блокировка обхода:** QUIC (UDP 443) и DoH (порт 853) от телевизоров блокируются (`DROP`).' >> README.md
echo '5. **Завершение обработки:** Пакет получает цель `ACCEPT`, что исключает его попадание в цепочку `ZALP_DPI`.' >> README.md
echo '' >> README.md
echo '| Команда | Описание |' >> README.md
echo '| --- | --- |' >> README.md
echo '| `fix start` | Включить перехват ТВ через VPN |' >> README.md
echo '| `fix stop` | Отключить перехват, вернуть трафик к Zalp |' >> README.md
echo '| `fix restart` | Перезапустить патч и policy routing |' >> README.md
echo '| `fix test` | Полная диагностика |' >> README.md
echo '' >> README.md

echo '## 🧪 Test Suite (Проверка стабильности)' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo ./tests/run_all_tests.sh' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo '**Что проверяется:**' >> README.md
echo '' >> README.md
echo '- Приоритет цепочек: `TV_VPN_FIX` на позиции 1, `ZALP_DPI` на позиции 2 (или позиция 1, если TV Fix не установлен).' >> README.md
echo '- Отсутствие конфликтов при запуске/остановке Mihomo.' >> README.md
echo '- Корректная работа `zalp doctor` по восстановлению правил.' >> README.md
echo '- Отсутствие дубликатов правил при многократном вызове.' >> README.md
echo '- Наличие DNAT для DNS в `TV_VPN_FIX` (критично для работы Smart TV).' >> README.md
echo '' >> README.md

echo '## 🧪 Встроенный Blockcheck' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo zalp test' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo '1. Введите домен для теста (например, `www.youtube.com`).' >> README.md
echo '2. Выберите режим `standard`.' >> README.md
echo '3. Дождитесь окончания (5-10 минут).' >> README.md
echo '4. Найдите строку `--- WORKING strategy for nfqws: ...`.' >> README.md
echo '5. Обновите параметры в `/etc/systemd/system/nfqws.service`.' >> README.md
echo '6. Перезапустите: `sudo zalp restart`.' >> README.md
echo '' >> README.md

echo '## 📦 Обновление продукта' >> README.md
echo '' >> README.md
echo '- Текущая версия хранится в `/opt/zalp/VERSION`.' >> README.md
echo '- Консоль проверяет релизы GitHub (кэш — 24 часа).' >> README.md
echo '- Обновление скачивает скрипты и запускает горячую замену через `restore.sh`.' >> README.md
echo '- Конфигурация `tv_macs.conf` сохраняется и восстанавливается автоматически.' >> README.md
echo '' >> README.md
echo '### Выпуск новой версии' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'git add -A && git commit -m "v5.2: описание изменений"' >> README.md
echo 'git tag v5.2' >> README.md
echo 'git push origin HEAD --tags' >> README.md
echo '```' >> README.md
echo '' >> README.md

echo '## 🔧 Конфигурация' >> README.md
echo '' >> README.md
echo '- `domains.txt` — список доменов для обхода DPI.' >> README.md
echo '- `domains-exclude.txt` — исключения.' >> README.md
echo '- `tv_macs.conf` — MAC-адреса телевизоров для TV Fix.' >> README.md
echo '' >> README.md
echo '### Стратегия обхода' >> README.md
echo '' >> README.md
echo '```text' >> README.md
echo '--dpi-desync=fakedsplit' >> README.md
echo '--dpi-desync-split-pos=1' >> README.md
echo '--dpi-desync-autottl' >> README.md
echo '--dpi-desync-fooling=badseq' >> README.md
echo '--dpi-desync-repeats=2' >> README.md
echo '```' >> README.md
echo '' >> README.md

echo '## 📋 Требования' >> README.md
echo '' >> README.md
echo '- **ОС:** Ubuntu 20.04+ / Debian 11+' >> README.md
echo '- **Права:** root (sudo)' >> README.md
echo '- **Сеть:** включен IP forwarding' >> README.md
echo '- **Зависимости:** устанавливаются автоматически' >> README.md
echo '' >> README.md

echo '## 🌐 Настройка клиентов' >> README.md
echo '' >> README.md
echo '- **Шлюз (Gateway):** IP вашего сервера (например, `192.168.10.100`)' >> README.md
echo '- **DNS:** IP вашего сервера или автоматически' >> README.md
echo '' >> README.md
echo '**Важно для Smart TV:** DNS на телевизоре должен быть в режиме **Автоматически**. TV Fix сам перехватит DNS-запросы и направит их в Mihomo.' >> README.md
echo '' >> README.md

echo '## 📝 Логи' >> README.md
echo '' >> README.md
echo '- `/var/log/zalp-doctor.log` — работа Doctor' >> README.md
echo '- `/var/log/zalp-install.log` — установка' >> README.md
echo '- Логи Mihomo: `journalctl -u mihomo`' >> README.md
echo '' >> README.md

echo '## 🐛 Troubleshooting' >> README.md
echo '' >> README.md
echo '### Обход не работает' >> README.md
echo '' >> README.md
echo '1. `sudo zalp` → Диагностика' >> README.md
echo '2. При устаревшей стратегии: `sudo zalp test`' >> README.md
echo '3. Примените параметры и выполните `sudo zalp restart`' >> README.md
echo '' >> README.md
echo '### TV Fix не работает (ТВ показывает «Нет подключения»)' >> README.md
echo '' >> README.md
echo '1. Убедитесь, что DNS на телевизоре стоит **Автоматически**.' >> README.md
echo '2. Проверьте policy routing для TPROXY:' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'ip rule show | grep fwmark' >> README.md
echo 'ip route show table 100' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo '*Если вывод пустой — выполните `sudo fix restart`.*' >> README.md
echo '' >> README.md
echo '3. Проверьте рост счетчиков TPROXY:' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo iptables -t mangle -L TV_VPN_FIX -n -v | grep TPROXY' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo '4. Проверьте наличие DNAT для DNS:' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo iptables -t nat -L TV_VPN_FIX -n -v | grep DNAT' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo '### Переустановка' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo ./restore.sh' >> README.md
echo '```' >> README.md
echo '' >> README.md

echo '## 📄 Лицензия' >> README.md
echo '' >> README.md
echo 'Проект использует zapret и Mihomo (MIT License).' >> README.md
echo '' >> README.md

echo '## 📋 Changelog v5.2' >> README.md
echo '' >> README.md
echo '- 🆕 Центральный конфиг `tv_macs.conf` для управления MAC-адресами TV Fix.' >> README.md
echo '- 🛡️ Добавлен DNAT для DNS (UDP 53) — критично для разрешения доменов на ТВ.' >> README.md
echo '- 🛡️ Автоматическое создание policy routing для TPROXY (`ip rule` + `ip route table 100`).' >> README.md
echo '- 🔧 Новая архитектура изоляции: `TV_VPN_FIX` на позиции 1, `ZALP_DPI` на позиции 2.' >> README.md
echo '- 🧪 Обновлен Test Suite с учетом новой архитектуры, добавлен `test_tv_fix_dns.sh`.' >> README.md
echo '- 📝 Исправлено сохранение конфига при `restore.sh`.' >> README.md
echo '' >> README.md
echo '---' >> README.md
echo '' >> README.md
echo '**Автор:** MamBoota' >> README.md
echo '**Версия:** 5.2' >> README.md
echo '**Дата:** 25 октября 2026' >> README.md

echo '✅ README.md успешно сгенерирован!'