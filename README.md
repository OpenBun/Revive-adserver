# Revive Adserver (OpenBun Docker build)

Docker image: [`openbun/revive-adserver:6.0.8-php8.3.36`](https://hub.docker.com/r/openbun/revive-adserver)

Based on Revive Adserver **6.0.8**, running on **PHP 8.3.36** (patched for [PHP2Shell](https://www.wiz.io/blog/php2shell-php-rce)).

---

## EasyPanel deploy (required)

EasyPanel **does not** auto-create env fields from a Docker image.  
You must paste the required variables into **Environment** before Deploy.

### 1) Source → Docker Image

| Field | Value |
| --- | --- |
| Image | `openbun/revive-adserver:6.0.8-php8.3.36` |
| Username / Password | leave empty (public image) |

### 2) Environment (copy / paste, then edit)

Use the ready file [`easypanel.env.example`](./easypanel.env.example), or paste:

```env
DB_TYPE=mysqli
DB_HOST=$(PROJECT_NAME)_mysql
DB_PORT=3306
DB_NAME=revive
DB_USER=revive
DB_PASSWORD=CHANGE_ME_DB_PASSWORD
DB_TABLE_PREFIX=rv_
DB_TABLE_TYPE=INNODB

ADMIN_USERNAME=admin
ADMIN_PASSWORD=CHANGE_ME_ADMIN_PASSWORD
ADMIN_EMAIL=admin@example.com
ADMIN_LANGUAGE=en

APP_HOSTNAME=$(PRIMARY_DOMAIN)
REQUIRE_SSL=0
SKIP_AUTO_INSTALL=0
```

**Required for auto-install**

| Variable | Required | Description |
| --- | --- | --- |
| `DB_HOST` | Yes* | MySQL hostname (EasyPanel MySQL service name) |
| `DB_PORT` | No | Default `3306` |
| `DB_NAME` | Yes* | Database name |
| `DB_USER` | Yes* | Database user |
| `DB_PASSWORD` | Yes* | Database password |
| `ADMIN_PASSWORD` | Yes | First admin password |
| `ADMIN_EMAIL` | Yes | First admin email |
| `APP_HOSTNAME` | Recommended | Public host without `http://` (e.g. `ads.example.com`) |
| `ADMIN_USERNAME` | No | Default `admin` |
| `REQUIRE_SSL` | No | `0` or `1` |
| `SKIP_AUTO_INSTALL` | No | `1` = skip CLI install, use web installer |
| `DATABASE_URL` | Optional | Alternative to `DB_*`, e.g. `mysql://user:pass@host:3306/revive` |

\* Or provide `DATABASE_URL` instead of the separate `DB_*` fields.

### 3) Domains / Port

- Container port: **80**
- Point your EasyPanel domain to this service

### 4) Mounts (recommended)

| Mount path | Purpose |
| --- | --- |
| `/var/www/html/var` | Persist config / install state |

### 5) MySQL

Create a MySQL service in the same EasyPanel project, create DB/user, then set `DB_HOST` / credentials above to match.

### What happens on Deploy

1. Container starts  
2. Creates `/var/www/html/.env` from `.env.example` if missing  
3. Loads EasyPanel env (overrides file values)  
4. If not installed yet and required vars are set → auto CLI install  
5. Apache serves the app → open `/www/admin` to log in  

---

## Docker Hub pull

```bash
docker pull openbun/revive-adserver:6.0.8-php8.3.36
```

Tags:

- `6.0.8-php8.3.36` — recommended
- `6.0.8` — same build, short alias

---

## Local quick test

```bash
docker run --rm -p 8080:80 \
  -e DB_HOST=mysql \
  -e DB_NAME=revive \
  -e DB_USER=revive \
  -e DB_PASSWORD=secret \
  -e ADMIN_PASSWORD=secret \
  -e ADMIN_EMAIL=admin@example.com \
  -e APP_HOSTNAME=localhost \
  openbun/revive-adserver:6.0.8-php8.3.36
```

---

## Upstream Revive Adserver

Revive Adserver is an open source ad serving tool that enables publishers to serve ads, manage campaigns, track performance, and apply targeting rules.

Official download: https://www.revive-adserver.com/download/

License: GPLv2 or later — see `LICENSE.txt` / `COPYRIGHT.txt`.

This product uses GeoLite2 data created by MaxMind: https://www.maxmind.com/
