# 🛡️ Zalp v5.2 — Умный обход DPI и управление сетью

**Zalp** — это комплексная, модульная система обхода DPI-блокировок и управления сетевым трафиком на базе zapret, оптимизированная для домашнего сервера или роутера. В версии 5.2 система получила критические исправления изоляции TV Fix, централизованную конфигурацию MAC-адресов и улучшенную стабильность TPROXY.

## ✨ Возможности

- 🚀 **Обход DPI**: YouTube, Instagram, Facebook, Threads и другие сервисы.
- 🛡️ **Стабильность iptables**: Изолированная цепочка `ZALP_DPI` предотвращает конфликты с Mihomo и TV Fix.
- 🩺 **Zalp Doctor**: Автоматическое самолечение и мониторинг каждые 5 минут.
- 🔄 **Горячая замена**: Переустановка и обновление без разрыва интернета.
- 🎛️ **Единая консоль `zalp`**: Управление всеми модулями из одного меню.
- 🌐 **Модуль Mihomo**: Прозрачный прокси (VLESS, Trojan, Shadowsocks и др.) с автоматической интеграцией.
- 📺 **TV Fix VPN**: Прозрачный VPN для Smart TV (LG, Samsung) без настройки на самом телевизоре.
- 🧪 **Test Suite**: Набор bash-тестов для проверки корректности работы модулей и правил.
- 📦 **Самообновление**: Следит за релизами на GitHub и обновляется в один клик.

## 📁 Структура проекта

```text
Zalp/
├── README.md             # Документация
├── install.sh            # Универсальный установщик v5.2
├── restore.sh            # Горячая замена и полный сброс
├── uninstall.sh          # Полное удаление
├── zalp-console.sh       # Единая панель управления (zalp)
├── tv_macs.conf          # Центральная конфигурация MAC-адресов TV Fix
├── create_readme.sh      # Генератор этого README
├── tests/                # Набор автоматических тестов
│   ├── run_all_tests.sh
│   ├── test_iptables_priority.sh
│   ├── test_systemd_order.sh
│   ├── test_mihomo_conflict.sh
│   ├── test_doctor_recovery.sh
│   ├── test_edge_cases.sh
│   └── test_tv_fix_dns.sh
├── mihomo/               # Модуль прозрачного прокси
│   ├── install_mihomo.sh
│   ├── uninstall_mihomo.sh
│   └── README.md
└── TV_FIX_VPN/           # Модуль прозрачного VPN для Smart TV
    ├── install-tv-fix-vpn.sh
    ├── uninstall-tv-fix-vpn.sh
    └── README.md
```

## 🚀 Быстрый старт

### Установка

```bash
git clone https://github.com/MamBoota/Zalp.git
cd Zalp
sudo ./install.sh
```

Установщик предложит настроить базовый обход DPI, а также опционально установить **Mihomo** и **TV Fix**.

### Единая консоль управления

```bash
sudo zalp
```

| Команда | Описание |
| --- | --- |
| `sudo zalp` | Интерактивная консоль управления |
| `sudo zalp start` | Запустить обход DPI |
| `sudo zalp stop` | Остановить обход DPI |
| `sudo zalp restart` | Безопасный перезапуск |
| `sudo zalp status` | Краткий статус всех модулей |
| `sudo zalp doctor` | Самолечение и восстановление правил iptables |
| `sudo zalp mihomo` | Меню управления прокси Mihomo |
| `sudo zalp tvfix` | Меню управления прозрачным VPN для ТВ |
| `sudo zalp test` | Запуск встроенного blockcheck.sh |
| `sudo zalp restore` | Полная очистка и горячая переустановка |

## 🌐 Модуль Mihomo (прозрачный прокси)

Mihomo — это прокси-ядро (Clash.Meta), которое позволяет использовать подписки VLESS/Trojan/Shadowsocks как прозрачный прокси.

### Автоматическая интеграция с Zalp

1. Запуск Mihomo гарантированно происходит **строго после** `nfqws` (Zalp).
2. После старта Mihomo автоматически вызывается `zalp doctor`, чтобы восстановить приоритет правил `ZALP_DPI`.

| Команда | Описание |
| --- | --- |
| `mihomo-start` | Запуск сервиса |
| `mihomo-stop` | Остановка |
| `mihomo-restart` | Перезапуск |
| `mihomo-test` | Диагностика (статус, узел, HTTP/HTTPS, внешний IP) |

## 📺 Модуль TV Fix VPN (прозрачный VPN для Smart TV)

TV Fix — это надстройка над Mihomo, которая перехватывает трафик Smart TV по MAC-адресу и прозрачно направляет его через VPN.

### ⚙️ Конфигурация TV Fix (ВАЖНО)

Начиная с версии 5.2, MAC-адреса телевизоров вынесены в центральный файл `/opt/zalp/tv_macs.conf`:

```text
SERVER_IP="192.168.10.100"  # IP сервера с Zalp (или "auto")
74:E6:B8:06:CD:8A           # MAC-адрес первого телевизора
04:B9:E3:4A:3C:EC           # MAC-адрес второго телевизора
```

*После изменения файла выполните `sudo fix restart` для применения правил.*

### Установка

```bash
sudo ./TV_FIX_VPN/install-tv-fix-vpn.sh
```

### 🛡 Как обеспечивается полная изоляция от Zalp

Архитектура гарантирует, что трафик ТВ и обычных устройств **никогда не пересекается**:

1. **Приоритет правил:** `TV_VPN_FIX` закреплена на **позиции 1** в `PREROUTING`, а `ZALP_DPI` — на позиции 2.
2. **Перехват DNS:** UDP-запросы на порт 53 от указанных MAC-адресов перенаправляются (DNAT) на внутренний DNS Mihomo (порт 1053).
3. **Прозрачный прокси (TPROXY):** TCP-трафик помечается маркой `fwmark 0x1`. Скрипт автоматически настраивает `policy routing` (`ip rule` + `ip route table 100`), чтобы ядро доставляло трафик в Mihomo.
4. **Блокировка обхода:** QUIC (UDP 443) и DoH (порт 853) от телевизоров блокируются (`DROP`).
5. **Завершение обработки:** Пакет получает цель `ACCEPT`, что исключает его попадание в цепочку `ZALP_DPI`.

| Команда | Описание |
| --- | --- |
| `fix start` | Включить перехват ТВ через VPN |
| `fix stop` | Отключить перехват, вернуть трафик к Zalp |
| `fix restart` | Перезапустить патч и policy routing |
| `fix test` | Полная диагностика |

## 🧪 Test Suite (Проверка стабильности)

```bash
sudo ./tests/run_all_tests.sh
```

**Что проверяется:**

- Приоритет цепочек: `TV_VPN_FIX` на позиции 1, `ZALP_DPI` на позиции 2 (или позиция 1, если TV Fix не установлен).
- Отсутствие конфликтов при запуске/остановке Mihomo.
- Корректная работа `zalp doctor` по восстановлению правил.
- Отсутствие дубликатов правил при многократном вызове.
- Наличие DNAT для DNS в `TV_VPN_FIX` (критично для работы Smart TV).

## 🧪 Встроенный Blockcheck

```bash
sudo zalp test
```

1. Введите домен для теста (например, `www.youtube.com`).
2. Выберите режим `standard`.
3. Дождитесь окончания (5-10 минут).
4. Найдите строку `--- WORKING strategy for nfqws: ...`.
5. Обновите параметры в `/etc/systemd/system/nfqws.service`.
6. Перезапустите: `sudo zalp restart`.

## 📦 Обновление продукта

- Текущая версия хранится в `/opt/zalp/VERSION`.
- Консоль проверяет релизы GitHub (кэш — 24 часа).
- Обновление скачивает скрипты и запускает горячую замену через `restore.sh`.
- Конфигурация `tv_macs.conf` сохраняется и восстанавливается автоматически.

### Выпуск новой версии

```bash
git add -A && git commit -m "v5.2: описание изменений"
git tag v5.2
git push origin HEAD --tags
```

## 🔧 Конфигурация

- `domains.txt` — список доменов для обхода DPI.
- `domains-exclude.txt` — исключения.
- `tv_macs.conf` — MAC-адреса телевизоров для TV Fix.

### Стратегия обхода

```text
--dpi-desync=fakedsplit
--dpi-desync-split-pos=1
--dpi-desync-autottl
--dpi-desync-fooling=badseq
--dpi-desync-repeats=2
```

## 📋 Требования

- **ОС:** Ubuntu 20.04+ / Debian 11+
- **Права:** root (sudo)
- **Сеть:** включен IP forwarding
- **Зависимости:** устанавливаются автоматически

## 🌐 Настройка клиентов

- **Шлюз (Gateway):** IP вашего сервера (например, `192.168.10.100`)
- **DNS:** IP вашего сервера или автоматически

**Важно для Smart TV:** DNS на телевизоре должен быть в режиме **Автоматически**. TV Fix сам перехватит DNS-запросы и направит их в Mihomo.

## 📝 Логи

- `/var/log/zalp-doctor.log` — работа Doctor
- `/var/log/zalp-install.log` — установка
- Логи Mihomo: `journalctl -u mihomo`

## 🐛 Troubleshooting

### Обход не работает

1. `sudo zalp` → Диагностика
2. При устаревшей стратегии: `sudo zalp test`
3. Примените параметры и выполните `sudo zalp restart`

### TV Fix не работает (ТВ показывает «Нет подключения»)

1. Убедитесь, что DNS на телевизоре стоит **Автоматически**.
2. Проверьте policy routing для TPROXY:

```bash
ip rule show | grep fwmark
ip route show table 100
```

*Если вывод пустой — выполните `sudo fix restart`.*

3. Проверьте рост счетчиков TPROXY:

```bash
sudo iptables -t mangle -L TV_VPN_FIX -n -v | grep TPROXY
```

4. Проверьте наличие DNAT для DNS:

```bash
sudo iptables -t nat -L TV_VPN_FIX -n -v | grep DNAT
```

### Переустановка

```bash
sudo ./restore.sh
```

## 📄 Лицензия

Проект использует zapret и Mihomo (MIT License).

## 📋 Changelog v5.2

- 🆕 Центральный конфиг `tv_macs.conf` для управления MAC-адресами TV Fix.
- 🛡️ Добавлен DNAT для DNS (UDP 53) — критично для разрешения доменов на ТВ.
- 🛡️ Автоматическое создание policy routing для TPROXY (`ip rule` + `ip route table 100`).
- 🔧 Новая архитектура изоляции: `TV_VPN_FIX` на позиции 1, `ZALP_DPI` на позиции 2.
- 🧪 Обновлен Test Suite с учетом новой архитектуры, добавлен `test_tv_fix_dns.sh`.
- 📝 Исправлено сохранение конфига при `restore.sh`.

---

**Автор:** MamBoota
**Версия:** 5.2
**Дата:** 25 октября 2026
