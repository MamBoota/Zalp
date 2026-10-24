#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║     Скрипт создания README.md для проекта Zalp       ║
# ║                    Версия 5.0                        ║
# ╚══════════════════════════════════════════════════════╝
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Создание README.md (v5.0)...${NC}"

# Очищаем файл
> README.md

# Заголовок
echo '# 🛡️ Zalp v5.0 — Умный обход DPI и управление сетью' >> README.md
echo '' >> README.md
echo '**Zalp** — это комплексная, модульная система обхода DPI-блокировок и управления сетевым трафиком на базе [zapret](https://github.com/bol-van/zapret), оптимизированная для домашнего сервера или роутера. В версии 5.0 система объединяет в себе обход DPI, прозрачный прокси (Mihomo), исправление маршрутизации для Smart TV и встроенную диагностику.' >> README.md
echo '' >> README.md

# Возможности
echo '## ✨ Возможности' >> README.md
echo '' >> README.md
echo '- 🚀 **Обход DPI**: YouTube, Instagram, Facebook, Threads и другие сервисы.' >> README.md
echo '- 🩺 **Zalp Doctor**: Автоматическое самолечение и мониторинг каждые 5 минут.' >> README.md
echo '- 🔄 **Горячая замена**: Переустановка и обновление без разрыва интернета.' >> README.md
echo '- 🎛️ **Единая консоль `zalp`**: Управление всеми модулями из одного меню.' >> README.md
echo '- 🌐 **Модуль Mihomo**: Встроенная поддержка прозрачного прокси (VLESS, Trojan, Shadowsocks и др.).' >> README.md
echo '- 📺 **TV Fix VPN**: Автоматический прозрачный VPN для Smart TV (LG, Samsung) без настройки на самом телевизоре.' >> README.md
echo '- 🧪 **Встроенный Blockcheck**: Автоматический подбор рабочих стратегий обхода для вашего провайдера.' >> README.md
echo '- 📦 **Самообновление**: Следит за релизами на GitHub и обновляется в один клик.' >> README.md
echo '' >> README.md

# Структура
echo '## 📁 Структура проекта' >> README.md
echo '' >> README.md
echo '```text' >> README.md
echo 'Zalp/' >> README.md
echo '├── README.md             # Документация' >> README.md
echo '├── install.sh            # Универсальный установщик v5.0' >> README.md
echo '├── restore.sh            # Горячая замена и полный сброс' >> README.md
echo '├── uninstall.sh          # Полное удаление' >> README.md
echo '├── zalp-console.sh       # Единая панель управления (устанавливается как `zalp`)' >> README.md
echo '├── create_readme.sh      # Генератор этого README' >> README.md
echo '├── mihomo/               # Модуль прозрачного прокси (опционально)' >> README.md
echo '│   ├── install_mihomo.sh' >> README.md
echo '│   ├── uninstall_mihomo.sh' >> README.md
echo '│   └── README.md' >> README.md
echo '└── TV_FIX_VPN/           # Модуль прозрачного VPN для Smart TV (опционально)' >> README.md
echo '    ├── install-tv-fix-vpn.sh' >> README.md
echo '    ├── uninstall-tv-fix-vpn.sh' >> README.md
echo '    └── README.md' >> README.md
echo '```' >> README.md
echo '' >> README.md

# Быстрый старт
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
echo 'Просто введите в терминале:' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo zalp' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo 'Откроется интерактивное меню со статусом всех систем, управлением DPI, прокси, ТВ и диагностикой.' >> README.md
echo '' >> README.md

# Команды управления
echo '### Команды управления' >> README.md
echo '' >> README.md
echo 'Все команды теперь объединены под одним интерфейсом `zalp`:' >> README.md
echo '' >> README.md
echo '| Команда | Описание |' >> README.md
echo '| --- | --- |' >> README.md
echo '| `sudo zalp` | Интерактивная консоль управления |' >> README.md
echo '| `sudo zalp start` | Запустить обход DPI |' >> README.md
echo '| `sudo zalp stop` | Остановить обход DPI |' >> README.md
echo '| `sudo zalp restart` | Безопасный перезапуск (с проверкой сети) |' >> README.md
echo '| `sudo zalp status` | Краткий статус всех модулей |' >> README.md
echo '| `sudo zalp doctor` | Ручной запуск самолечения |' >> README.md
echo '| `sudo zalp mihomo` | Меню управления прокси Mihomo |' >> README.md
echo '| `sudo zalp tvfix` | Меню управления прозрачным VPN для ТВ |' >> README.md
echo '| `sudo zalp test` | Запуск встроенного blockcheck.sh |' >> README.md
echo '| `sudo zalp restore` | Полная очистка и горячая переустановка |' >> README.md
echo '' >> README.md

# Модуль Mihomo
echo '## 🌐 Модуль Mihomo (прозрачный прокси)' >> README.md
echo '' >> README.md
echo 'Mihomo — это прокси-ядро (Clash.Meta), которое позволяет использовать подписки VLESS/Trojan/Shadowsocks как прозрачный прокси.' >> README.md
echo '' >> README.md
echo '### Установка' >> README.md
echo '' >> README.md
echo 'При установке Zalp вам будет предложено установить Mihomo. Либо вручную:' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo ./mihomo/install_mihomo.sh' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo 'Скрипт запросит URL подписки от вашего VPN-провайдера.' >> README.md
echo '' >> README.md

echo '### Команды' >> README.md
echo '' >> README.md
echo '| Команда | Описание |' >> README.md
echo '| --- | --- |' >> README.md
echo '| `mihomo-start` | Запуск сервиса |' >> README.md
echo '| `mihomo-stop` | Остановка |' >> README.md
echo '| `mihomo-restart` | Перезапуск |' >> README.md
echo '| `mihomo-test` | Диагностика (статус, активный узел, HTTP/HTTPS, внешний IP) |' >> README.md
echo '' >> README.md

echo '### Watchdog' >> README.md
echo '' >> README.md
echo 'Mihomo автоматически перезапускается каждые 5 минут при падении (cron).' >> README.md
echo '' >> README.md

# Модуль TV Fix VPN
echo '## 📺 Модуль TV Fix VPN (прозрачный VPN для Smart TV)' >> README.md
echo '' >> README.md
echo 'TV Fix — это надстройка над Mihomo, которая перехватывает трафик Smart TV по MAC-адресу и прозрачно направляет его через VPN.' >> README.md
echo '' >> README.md
echo '### Установка' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo ./TV_FIX_VPN/install-tv-fix-vpn.sh' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo '⚠️ **Важно**: Перед установкой откройте `install-tv-fix-vpn.sh` и пропишите MAC-адреса своих телевизоров:' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'TV_MAC_1="74:E6:B8:06:CD:8A"   # LG WebOS' >> README.md
echo 'TV_MAC_2=""                     # Samsung Tizen 1' >> README.md
echo 'TV_MAC_3=""                     # Samsung Tizen 2' >> README.md
echo '```' >> README.md
echo '' >> README.md

echo '### Как это работает' >> README.md
echo '' >> README.md
echo '- Перехватывает трафик ТВ по MAC-адресу (без настроек на самом TV)' >> README.md
echo '- Блокирует QUIC и DoH (UDP 443, TCP/UDP 853) — чтобы ТВ не обходил прокси' >> README.md
echo '- Перенаправляет DNS-запросы ТВ на внутренний резолвер Mihomo' >> README.md
echo '- Автоматический fallback на Zalp при падении VPN' >> README.md
echo '- Watchdog проверяет каждые 3 минуты' >> README.md
echo '' >> README.md

echo '### Команды' >> README.md
echo '' >> README.md
echo '| Команда | Описание |' >> README.md
echo '| --- | --- |' >> README.md
echo '| `fix start` | Включить перехват ТВ через VPN |' >> README.md
echo '| `fix stop` | Отключить перехват, вернуть трафик к Zalp |' >> README.md
echo '| `fix restart` | Перезапустить патч |' >> README.md
echo '| `fix test` | Полная диагностика |' >> README.md
echo '' >> README.md

# Blockcheck
echo '## 🧪 Встроенный Blockcheck' >> README.md
echo '' >> README.md
echo 'Если обход перестал работать, используйте встроенный инструмент:' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo zalp test' >> README.md
echo '# или напрямую:' >> README.md
echo 'cd /opt/zalp' >> README.md
echo 'sudo ./blockcheck.sh' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo 'Следуйте инструкциям:' >> README.md
echo '' >> README.md
echo '1. Введите домен для теста (например, `www.youtube.com`)' >> README.md
echo '2. Выберите `standard` режим' >> README.md
echo '3. Дождитесь окончания (5-10 минут)' >> README.md
echo '4. Найдите строку `--- WORKING strategy for nfqws: ...`' >> README.md
echo '5. Обновите параметры в `/etc/systemd/system/nfqws.service`' >> README.md
echo '6. Перезапустите: `sudo zalp restart`' >> README.md
echo '' >> README.md

# Обновление
echo '## 📦 Обновление продукта' >> README.md
echo '' >> README.md
echo 'Консоль сама следит за обновлениями:' >> README.md
echo '' >> README.md
echo '- Текущая версия хранится в `/opt/zalp/VERSION`' >> README.md
echo '- При старте консоли проверяются теги/релизы репозитория на GitHub (кэш проверки — 24 часа)' >> README.md
echo '- При обнаружении новой версии в панели появляется аларм' >> README.md
echo '- Пункт **9** скачивает новые `install.sh`, `restore.sh`, `uninstall.sh`, `zalp-console.sh` и запускает горячую замену через `restore.sh` — интернет не прерывается' >> README.md
echo '' >> README.md

echo '### Выпуск новой версии (для сопровождающего)' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo '# 1. Поднять версию в install.sh (баннер и файл VERSION)' >> README.md
echo '# 2. Закоммитить изменения' >> README.md
echo 'git add -A && git commit -m "v5.1: описание изменений"' >> README.md
echo '# 3. Создать тег и запушить' >> README.md
echo 'git tag v5.1' >> README.md
echo 'git push origin HEAD --tags' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo 'После этого все установленные копии увидят аларм об обновлении в консоли.' >> README.md
echo '' >> README.md

# Конфигурация
echo '## 🔧 Конфигурация' >> README.md
echo '' >> README.md
echo '### Списки доменов' >> README.md
echo '' >> README.md
echo 'Файлы конфигурации находятся в `/opt/zalp/`:' >> README.md
echo '' >> README.md
echo '- `domains.txt` — список доменов для обхода DPI' >> README.md
echo '- `domains-exclude.txt` — исключения (корпоративные сервисы)' >> README.md
echo '' >> README.md

echo '### Стратегия обхода' >> README.md
echo '' >> README.md
echo 'Текущая стратегия в `/etc/systemd/system/nfqws.service`:' >> README.md
echo '' >> README.md
echo '```' >> README.md
echo '--dpi-desync=fakedsplit' >> README.md
echo '--dpi-desync-split-pos=1' >> README.md
echo '--dpi-desync-autottl' >> README.md
echo '--dpi-desync-fooling=badseq' >> README.md
echo '--dpi-desync-repeats=2' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo 'Оптимизирована для стриминга видео (4K, Shorts, Reels) с минимальными задержками.' >> README.md
echo '' >> README.md

# Требования
echo '## 📋 Требования' >> README.md
echo '' >> README.md
echo '- **ОС:** Ubuntu 20.04+ / Debian 11+' >> README.md
echo '- **Права:** root (sudo)' >> README.md
echo '- **Сеть:** сервер должен работать как роутер (IP forwarding)' >> README.md
echo '- **Зависимости:** устанавливаются автоматически' >> README.md
echo '' >> README.md

# Настройка клиентов
echo '## 🌐 Настройка клиентов' >> README.md
echo '' >> README.md
echo 'Чтобы клиенты (телефоны, ноутбуки, ТВ) использовали Zalp:' >> README.md
echo '' >> README.md
echo '1. Подключите их к Wi-Fi/Ethernet вашего сервера' >> README.md
echo '2. В настройках сети укажите:' >> README.md
echo '   - **Шлюз (Gateway):** IP вашего сервера' >> README.md
echo '   - **DNS:** IP вашего сервера (или любой публичный DNS)' >> README.md
echo '' >> README.md
echo 'Пример для роутера:' >> README.md
echo '' >> README.md
echo '```' >> README.md
echo 'Шлюз: 192.168.1.50' >> README.md
echo 'DNS: 192.168.1.50' >> README.md
echo '```' >> README.md
echo '' >> README.md

# Консоли
echo '## 🎮 Поддержка консолей (Xbox, PlayStation)' >> README.md
echo '' >> README.md
echo 'Для Xbox и PlayStation рекомендуется настроить **прямое подключение** к основному роутеру (шлюз = основной роутер), чтобы избежать Double NAT.' >> README.md
echo '' >> README.md

# Логи
echo '## 📝 Логи' >> README.md
echo '' >> README.md
echo '- `/var/log/zalp-doctor.log` — лог работы Doctor' >> README.md
echo '- `/var/log/zalp-install.log` — лог установки' >> README.md
echo '- `/var/log/tv_fix_vpn.log` — лог TV Fix VPN (если установлен)' >> README.md
echo '' >> README.md

# Полное удаление
echo '## 🗑️ Полное удаление' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo ./uninstall.sh' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo 'Скрипт удалит:' >> README.md
echo '- Каталог `/opt/zalp` (движок + конфиги)' >> README.md
echo '- Systemd-сервис `nfqws`' >> README.md
echo '- Cron-задачу Doctor' >> README.md
echo '- Команды управления `zalp-*`' >> README.md
echo '- Логи `/var/log/zalp-*.log`' >> README.md
echo '- Правила NFQUEUE в iptables/ip6tables' >> README.md
echo '' >> README.md
echo 'Что **НЕ** трогает (намеренно):' >> README.md
echo '- IP forwarding в `/etc/sysctl.conf`' >> README.md
echo '- Базовый NAT и FORWARD (роутинг работает)' >> README.md
echo '- Сетевые интерфейсы' >> README.md
echo '' >> README.md

# Troubleshooting
echo '## 🐛 Troubleshooting' >> README.md
echo '' >> README.md
echo '### Обход не работает' >> README.md
echo '' >> README.md
echo '1. Откройте `sudo zalp` → пункт 2 (Диагностика)' >> README.md
echo '2. Если стратегия устарела, выберите пункт "Тестирование (Blockcheck)" для подбора новой' >> README.md
echo '3. Примените новую стратегию и выполните `sudo zalp restart`' >> README.md
echo '' >> README.md

echo '### Нет интернета после установки' >> README.md
echo '' >> README.md
echo '1. Выполните `sudo zalp stop`' >> README.md
echo '2. Если интернет появился, проблема в стратегии' >> README.md
echo '3. Запустите `sudo zalp test` для подбора рабочей' >> README.md
echo '' >> README.md

echo '### Mihomo не отвечает' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo mihomo-test' >> README.md
echo 'sudo mihomo-restart' >> README.md
echo '```' >> README.md
echo '' >> README.md

echo '### TV Fix не работает' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo fix test' >> README.md
echo '# Проверьте, что MAC-адрес ТВ совпадает с прописанным в скрипте' >> README.md
echo '```' >> README.md
echo '' >> README.md

echo '### Переустановка' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo ./restore.sh' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo 'Это полностью очистит систему и переустановит Zalp без разрыва интернета.' >> README.md
echo '' >> README.md

# Лицензия
echo '## 📄 Лицензия' >> README.md
echo '' >> README.md
echo 'Этот проект использует [zapret](https://github.com/bol-van/zapret) и [Mihomo](https://github.com/MetaCubeX/mihomo) (MIT License).' >> README.md
echo '' >> README.md

echo '## 🤝 Вклад' >> README.md
echo '' >> README.md
echo 'Проблемы и предложения приветствуются в Issues!' >> README.md
echo '' >> README.md
echo '---' >> README.md
echo '' >> README.md
echo '**Автор:** [MamBoota](https://github.com/MamBoota)  ' >> README.md
echo '**Версия:** 5.0  ' >> README.md
echo '**Дата:** Октябрь 2026' >> README.md

echo -e "${GREEN}✅ README.md (v5.0) успешно создан!${NC}"
ls -la README.md