# 🚀 Mihomo Auto-Setup

Автоматическая установка, настройка и управление прокси-сервером **[Mihomo](https://github.com/MetaCubeX/mihomo)** (Clash.Meta) на Linux (x86_64).

Скрипты разворачивают Mihomo как системный сервис `systemd`, настраивают автовыбор самого быстрого узла из подписки, добавляют удобные команды управления и watchdog для автоматического перезапуска при сбоях.

---

## ✨ Возможности

- 🧹 Полная очистка предыдущих установок перед развёртыванием
- 📦 Установка Mihomo `v1.19.33` (linux-amd64-compatible) в `/usr/local/bin`
- ⚙️ Готовая конфигурация:
  - HTTP/SOCKS5 прокси на порту `7890`
  - TUN-режим с системным стеком
  - DNS в режиме `fake-ip` (Cloudflare + Google DoH)
  - Sniffer для TLS/HTTP
  - Автоматический выбор самого быстрого узла (`url-test`)
- 🤖 Systemd-сервис с автоперезапуском (`Restart=always`)
- 🛠️ 4 удобные команды: `mihomo-start`, `mihomo-stop`, `mihomo-restart`, `mihomo-test`
- 👁️ Watchdog в `cron` — проверка каждые 5 минут, автоперезапуск при падении

---

## 📋 Требования

- Linux (x86_64, glibc)
- `root`-права (или `sudo`)
- Утилиты: `bash`, `wget`, `gzip`, `curl`, `systemctl`, `cron`
- Доступ в интернет для загрузки бинарника и подписки

---

## 📥 Установка

```bash
# Скачиваем установочный скрипт
wget https://raw.githubusercontent.com/<ваш-репо>/main/install_mihomo.sh

# Делаем исполняемым и запускаем
chmod +x install_mihomo.sh
sudo ./install_mihomo.sh
```

Скрипт выполнит 7 этапов:
1. Очистка старых установок
2. Загрузка Mihomo
3. Создание конфигурации (`/etc/mihomo/config.yaml`)
4. Регистрация systemd-сервиса
5. Создание команд управления
6. Первичный тест (`mihomo-test`)
7. Установка watchdog в cron

> 💡 **Важно:** Во время установки скрипт сам остановится и запросит у вас URL подписки от вашего поставщика VPN-услуг. Просто вставьте ссылку и нажмите `Enter` — она автоматически подставится в конфигурацию.

---

## 🎮 Команды управления

После установки в системе доступны 4 глобальные команды:

| Команда            | Описание                                  |
|--------------------|-------------------------------------------|
| `mihomo-start`     | ▶️ Запуск сервиса                         |
| `mihomo-stop`      | ⏹️ Остановка сервиса                      |
| `mihomo-restart`   | 🔄 Перезапуск сервиса                     |
| `mihomo-test`      | 🔍 Диагностика: статус, активный узел, HTTP/HTTPS, внешний IP |

### Пример использования

```bash
mihomo-test
```

Вывод:
```
==========================================================
🔍 ДИАГНОСТИКА MIHOMO
==========================================================
✅ Статус сервиса: ACTIVE (Работает)
✅ Активный узел: 🇳🇱 Netherlands 01
✅ HTTP прокси: ОК (Код: 204)
✅ HTTPS прокси: ОК (Код: 200)
✅ Внешний IP через прокси: 185.xxx.xxx.xxx
==========================================================
```

---

## 🧩 Структура файлов после установки

| Путь                                  | Назначение                            |
|---------------------------------------|---------------------------------------|
| `/usr/local/bin/mihomo`               | Исполняемый файл Mihomo               |
| `/usr/local/bin/mihomo-start`         | Команда запуска                       |
| `/usr/local/bin/mihomo-stop`          | Команда остановки                     |
| `/usr/local/bin/mihomo-restart`       | Команда перезапуска                   |
| `/usr/local/bin/mihomo-test`          | Команда диагностики                   |
| `/etc/mihomo/config.yaml`             | Основной конфиг                       |
| `/etc/mihomo/providers/my-sub.yaml`   | Скачанная подписка (автообновление)   |
| `/etc/systemd/system/mihomo.service`  | Systemd-юнит                          |
| `/opt/mihomo/`                        | Рабочая директория                    |

### Ключевые порты

| Порт   | Назначение                         |
|--------|------------------------------------|
| `7890` | HTTP / SOCKS5 / Mixed прокси       |
| `9090` | RESTful API (только `127.0.0.1`)   |
| `1053` | Внутренний DNS-резолвер            |

---

## 🔄 Использование прокси

### В терминале (разово)
```bash
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
curl https://www.google.com
```

### В браузере
Укажите прокси `127.0.0.1:7890` (SOCKS5 или HTTP) в настройках браузера или расширения (FoxyProxy, SwitchyOmega).

### Через API (переключение узла)
```bash
# Получить текущий узел
curl -s http://127.0.0.1:9090/proxies/AUTO-FASTEST | jq .now

# Переключить на конкретный узел
curl -X PUT http://127.0.0.1:9090/proxies/AUTO-FASTEST \
  -H "Content-Type: application/json" \
  -d '{"name":"🇩🇪 Germany 02"}'
```

---

## 🗑️ Полное удаление

```bash
wget https://raw.githubusercontent.com/<ваш-репо>/main/uninstall_mihomo.sh
chmod +x uninstall_mihomo.sh
sudo ./uninstall_mihomo.sh
```

Скрипт удалит:
- systemd-сервис и его счётчики
- бинарник Mihomo и все 4 команды управления
- директории `/etc/mihomo` и `/opt/mihomo`
- задачу watchdog из `cron`
- следы в `nftables` и `iptables` (таблицы `mihomo_zalp`, `MIHOMO_TPROXY`)

После выполнения система возвращается в исходное чистое состояние.

---

## 🐛 Troubleshooting

| Проблема                              | Решение                                              |
|---------------------------------------|------------------------------------------------------|
| `mihomo-test` показывает ❌ СБОЙ      | `journalctl -u mihomo -n 30` — смотреть логи         |
| Подписка не грузится                  | Проверьте URL в `/etc/mihomo/config.yaml`            |
| Сервис падает                         | Watchdog в cron автоматически его поднимет            |
| Нет интернета после `mihomo-start`    | Проверьте, что не включён TUN + `auto-route` конфликт |
| Нужно сменить подписку                | Отредактируйте `config.yaml` → `mihomo-restart`      |

### Просмотр логов в реальном времени
```bash
journalctl -u mihomo -f
```

### Ручная проверка конфига
```bash
/usr/local/bin/mihomo -t -d /etc/mihomo
```

---

## 📄 Лицензия

Скрипты распространяются "как есть", без каких-либо гарантий.  
Mihomo распространяется под собственной лицензией — см. [репозиторий MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo).

---

## 🙏 Благодарности

- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) — ядро прокси
- Авторам скриптов автоматизации
- [MamBoota] (https://github.com/MamBoota)