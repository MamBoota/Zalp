#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║     Скрипт создания README.md для проекта Zalp       ║
# ║                    Версия 5.1                        ║
# ╚══════════════════════════════════════════════════════╝
set -e
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Создание README.md (v5.1)...${NC}"

# Очищаем файл
> README.md

# Заголовок
echo '# 🛡️ Zalp v5.1 — Умный обход DPI и управление сетью' >> README.md
echo '' >> README.md
echo '**Zalp** — это комплексная, модульная система обхода DPI-блокировок и управления сетевым трафиком на базе [zapret](https://github.com/bol-van/zapret), оптимизированная для домашнего сервера или роутера. В версии 5.1 система получила усиленную защиту от конфликтов правил `iptables` и встроенный набор автоматических тестов (Test Suite).' >> README.md
echo '' >> README.md

# Возможности
echo '## ✨ Возможности' >> README.md
echo '' >> README.md
echo '- 🚀 **Обход DPI**: YouTube, Instagram, Facebook, Threads и другие сервисы.' >> README.md
echo '- 🛡️ **Стабильность iptables**: Изолированная цепочка `ZALP_DPI` предотвращает конфликты с Mihomo и TV Fix, гарантируя приоритет обработки.' >> README.md
echo '- 🩺 **Zalp Doctor**: Автоматическое самолечение и мониторинг каждые 5 минут.' >> README.md
echo '- 🔄 **Горячая замена**: Переустановка и обновление без разрыва интернета.' >> README.md
echo '- 🎛️ **Единая консоль `zalp`**: Управление всеми модулями из одного меню.' >> README.md
echo '- 🌐 **Модуль Mihomo**: Встроенная поддержка прозрачного прокси (VLESS, Trojan, Shadowsocks и др.) с автоматической интеграцией.' >> README.md
echo '- 📺 **TV Fix VPN**: Автоматический прозрачный VPN для Smart TV (LG, Samsung) без настройки на самом телевизоре.' >> README.md
echo '- 🧪 **Test Suite**: Встроенный набор bash-тестов для проверки корректности работы всех модулей и правил.' >> README.md
echo '- 📦 **Самообновление**: Следит за релизами на GitHub и обновляется в один клик.' >> README.md
echo '' >> README.md

# Структура
echo '## 📁 Структура проекта' >> README.md
echo '' >> README.md
echo '```text' >> README.md
echo 'Zalp/' >> README.md
echo '├── README.md             # Документация' >> README.md
echo '├── install.sh            # Универсальный установщик v5.1' >> README.md
echo '├── restore.sh            # Горячая замена и полный сброс' >> README.md
echo '├── uninstall.sh          # Полное удаление' >> README.md
echo '├── zalp-console.sh       # Единая панель управления (устанавливается как `zalp`)' >> README.md
echo '├── create_readme.sh      # Генератор этого README' >> README.md
echo '├── tests/                # Набор автоматических тестов (Test Suite)' >> README.md
echo '│   ├── run_all_tests.sh  # Главный скрипт запуска тестов' >> README.md
echo '│   └── test_*.sh         # Отдельные сценарии проверки' >> README.md
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
echo '| `sudo zalp doctor` | Ручной запуск самолечения и восстановление правил iptables |' >> README.md
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
echo '### Автоматическая интеграция с Zalp' >> README.md
echo '' >> README.md
echo 'При установке Mihomo скрипт автоматически создает `systemd drop-in override`, который:' >> README.md
echo '1. Гарантирует запуск Mihomo **строго после** `nfqws` (Zalp).' >> README.md
echo '2. Автоматически вызывает `zalp doctor` после старта Mihomo, чтобы восстановить приоритет правил `ZALP_DPI`, если Mihomo попытался их изменить.' >> README.md
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

# Test Suite
echo '## 🧪 Test Suite (Проверка стабильности)' >> README.md
echo '' >> README.md
echo 'В проект встроен набор автоматических тестов для проверки корректности работы `iptables`, порядка запуска сервисов и устойчивости к конфликтам.' >> README.md
echo '' >> README.md
echo '```bash' >> README.md
echo 'sudo ./tests/run_all_tests.sh' >> README.md
echo '```' >> README.md
echo '' >> README.md
echo '**Что проверяется:**' >> README.md
echo '- Приоритет цепочки `ZALP_DPI` в `PREROUTING` (должна быть на позиции 1).' >> README.md
echo '- Отсутствие конфликтов при запуске/остановке Mihomo.' >> README.md
echo '- Корректная работа `zalp doctor` по восстановлению правил.' >> README.md
echo '- Отсутствие дубликатов правил при многократном вызове.' >> README.md
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

# Обновление
echo '## 📦 Обновление продукта' >> README.md
echo '' >> README.md
echo 'Консоль сама следит за обновлениями:' >> README.md
echo '' >> README.md
echo '- Текущая версия хранится в `/opt/zalp/VERSION`' >> README.md
echo '- При старте консоли проверяются теги/релизы репозитория на GitHub (кэш проверки — 24 часа)' >> README.md
echo '- При обнаружении новой версии в панели появляется аларм' >> README.md
echo '- Скачивание новых скриптов и запуск горячей замены через `restore.sh` (интернет не прерывается)' >> README.md
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

# Требования
echo '## 📋 Требования' >> README.md
echo '' >> README.md
echo '- **ОС:** Ubuntu 20.04+ / Debian 11+' >> README.md
echo '- **Права:** root (sudo)' >> README.md
echo '- **Сеть:** сервер должен работать как роутер (IP forwarding)' >> README.md
echo '- **Зависимости:** устанавливаются автоматически' >> README.md
echo '' >> README.md

# Логи
echo '## 📝 Логи' >> README.md
echo '' >> README.md
echo '- `/var/log/zalp-doctor.log` — лог работы Doctor' >> README.md
echo '- `/var/log/zalp-install.log` — лог установки' >> README.md
echo '- `/var/log/tv_fix_vpn.log` — лог TV Fix VPN (если установлен)' >> README.md
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
echo '### Подозрение на сбой правил iptables' >> README.md
echo '' >> README.md
echo 'Запустите тесты для мгновенной диагностики:' >> README.md
echo '```bash' >> README.md
echo 'sudo ./tests/run_all_tests.sh' >> README.md
echo 'sudo zalp doctor' >> README.md
echo '```' >> README.md
echo '' >> README.md

# Лицензия и авторы
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
echo '**Версия:** 5.1  ' >> README.md
echo '**Дата:** Октябрь 2026' >> README.md

echo -e "${GREEN}✅ README.md (v5.1) успешно создан!${NC}"
ls -la README.md