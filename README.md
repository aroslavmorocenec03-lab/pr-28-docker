# Практична робота №28

## Робота з Docker

Статичний сайт на Nginx у Linux-контейнері з Dockerfile, публікацією порту, перевіркою стану, початковою та оновленою версіями сайту. Додано сценарії базових операцій Docker, перебудови контейнера та збору фактичних результатів.

**Стан виконання та результати перевірки наведено у [звіті](reports/REPORT.md).**

## Перед запуском

Потрібен запущений **Docker Desktop у режимі Linux containers**. На Windows використовується WSL 2. Після першого встановлення компонентів Windows може знадобитися перезавантаження. Умови Docker Desktop приймає користувач у самому застосунку.

Перевірка середовища:

```powershell
docker --help
docker compose --help
docker version
docker info --format '{{.OSType}}'
```

Остання команда має повернути `linux`. У сучасному Docker Desktop Compose запускається як `docker compose`. Команду `docker-compose` із документа можна перевірити додатково, якщо встановлено сумісний виконуваний файл.

## Швидкий запуск сайту

У терміналі в папці з Dockerfile:

```powershell
docker build -t my-static-website .
docker run -d --name static-website --label ua.pr28.project=pr-28-docker -p 127.0.0.1:8080:80 my-static-website
```

Відкрийте **http://localhost:8080**. Якщо 8080 зайнятий, використайте, наприклад, `127.0.0.1:8081:80` та адресу `http://localhost:8081`.

`EXPOSE 80` у Dockerfile описує порт програми всередині контейнера. Саме `-p` публікує його на комп’ютері. Прив’язка до `127.0.0.1` робить навчальний сайт доступним локально.

## Послідовність для виконання всіх пунктів

Сценарії розраховані на PowerShell. Їх слід запускати з відкритого термінала, у якому доступна команда `docker`. Якщо політика Windows блокує `.ps1`, основні команди можна виконати вручну, як наведено нижче; змінювати системну політику не потрібно.

```powershell
# 1. hello-world, busybox, images, ps, start, stop, rm.
.\scripts\Run-Basics.ps1

# 2. Початкова сторінка з прикладу завдання: образ my-static-website:v1.
.\scripts\Start-Website.ps1 -Initial

# 3. Оновлений власний сайт: перебудова образу та перестворення контейнера.
.\scripts\Start-Website.ps1

# 4. Фактичні списки образів і контейнерів, статистика та HTTP-перевірка.
.\scripts\Collect-Evidence.ps1
```

Для іншого порту передайте, наприклад, `-Port 8081` у сценарії запуску та збору результатів. `Start-Website.ps1` перевіряє `healthy` і відповідь HTTP 200. У фінальному варіанті він також перевіряє маркер `data-site-version="2"`, щоб не прийняти старий сайт за оновлений.

Сценарій перебудови зупиняє та видаляє наявний `static-website` лише тоді, коли він має мітку цього проєкту. Якщо контейнер із такою назвою належить іншому проєкту, сценарій зупиниться з поясненням. Загальні команди `prune` та примусове видалення ресурсів не використовуються.

## Основні команди першої частини

```powershell
docker run --name pr28-hello --label ua.pr28.project=pr-28-docker hello-world
docker pull busybox
docker images
docker image inspect busybox --format '{{.Id}}'
# Скопіюйте саме отриманий ID; образ має не використовуватися контейнерами.
docker image rm <IMAGE_ID>
docker pull busybox
docker run --name pr28-busybox --label ua.pr28.project=pr-28-docker busybox echo "hello from busybox"
docker ps
docker ps -a
docker start pr28-busybox
docker stop pr28-busybox
docker rm pr28-busybox
```

BusyBox із командою `echo` виконує дію та завершується. Тому його може не бути в `docker ps`, але він буде в `docker ps -a`, доки контейнер не видалено.

## Що робить Dockerfile

```dockerfile
FROM nginx:stable-alpine
LABEL ua.pr28.project="pr-28-docker"
COPY ./html /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
```

- `FROM` задає офіційний образ Nginx на Alpine Linux.
- `COPY` додає сайт до образу.
- `EXPOSE` описує порт 80.
- `HEALTHCHECK` періодично перевіряє HTTP-відповідь Nginx.
- `CMD` залишає Nginx у foreground, тому основний процес контейнера продовжує працювати.
- `LABEL` допомагає сценаріям розпізнавати власні контейнери.

## Оновлення без bind mount

Після зміни `html/` старий контейнер автоматично не оновлюється: у ньому залишаються файли попереднього образу. Потрібно перебудувати образ і створити контейнер заново. Це робить `Start-Website.ps1`.

Для ручного повторення після перевірки, що `static-website` — саме контейнер цієї роботи:

```powershell
docker stop static-website
docker rm static-website
docker build -t my-static-website .
docker run -d --name static-website --label ua.pr28.project=pr-28-docker -p 127.0.0.1:8080:80 my-static-website
```

## Варіант із підключенням папки

`compose.yaml` додає read-only bind mount `./html` у `/usr/share/nginx/html`. Це окремий режим для перевірки томів: зміни локальних файлів одразу видно в контейнері після оновлення сторінки, оскільки підключена папка перекриває вміст, скопійований в образ.

Перед переходом на Compose зупиніть і видаліть свій попередній контейнер `static-website`, щоб звільнити назву та порт. Потім:

```powershell
docker compose config
docker compose up -d --build
docker compose ps
docker compose logs --tail 20
docker compose down
```

Bind mount із `read_only: true` дозволяє контейнеру читати сайт, але не змінювати ці файли на комп’ютері. Docker volume, на відміну від bind mount, зберігається в каталозі, яким керує Docker.

## Моніторинг

```powershell
docker ps --filter label=ua.pr28.project=pr-28-docker
docker logs --tail 20 static-website
docker inspect --format '{{.State.Health.Status}}' static-website
docker stats --no-stream static-website
```

## Звіт і скриншоти

`reports/REPORT.md` містить звіт та відповіді на контрольні запитання. `Collect-Evidence.ps1` після справжнього запуску створює текстові результати та `reports/evidence.html` для їх перегляду. Скриншоти потрібно робити з фактичних результатів Docker і сайту на опублікованому порту; звичайний перегляд HTML без контейнера не доводить його запуск.

## Файли

```text
Dockerfile                    образ Nginx і healthcheck
html/index.html               оновлена сторінка, версія 2
html/style.css                оформлення сайту
examples/index.initial.html   початкова сторінка із завдання
compose.yaml                  варіант із read-only bind mount
scripts/                      базові операції, запуск і збір результатів
reports/REPORT.md             звіт та контрольні запитання
```

Джерела: [встановлення Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/), [Dockerfile](https://docs.docker.com/reference/dockerfile/), [Docker Compose](https://docs.docker.com/reference/cli/docker/compose/), [bind mounts](https://docs.docker.com/engine/storage/bind-mounts/).
