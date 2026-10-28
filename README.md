# Revive Adserver (OpenBun Docker build)

Docker image: [`openbun/revive-adserver`](https://hub.docker.com/r/openbun/revive-adserver)

Based on Revive Adserver **6.0.8**, running on **PHP 8.3.36** (patched for [PHP2Shell](https://www.wiz.io/blog/php2shell-php-rce)).

### Image tags (use these)

| Tag | Meaning |
| --- | --- |
| `6.0.8` | **Recommended** — Revive version |
| `v6.0.8` | Same build, `v` prefix |
| `latest` | Latest published build |
| `6.0.8-php8.3.36` | Explicit PHP pin (optional) |

EasyPanel / Docker example:

```text
openbun/revive-adserver:6.0.8
```

---

## EasyPanel deploy (required)

EasyPanel **does not** auto-create env fields from a Docker image.  
You must paste the required variables into **Environment** before Deploy.

### 1) Source → Docker Image

| Field | Value |
| --- | --- |
| Image | `openbun/revive-adserver:6.0.8` |
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

ADMIN_USERNAME=admin
ADMIN_PASSWORD=CHANGE_ME_ADMIN_PASSWORD
ADMIN_EMAIL=admin@example.com
ADMIN_LANGUAGE=en

APP_HOSTNAME=$(PRIMARY_DOMAIN)
REQUIRE_SSL=0
SKIP_AUTO_INSTALL=0
```

**Critical: `DB_HOST`**

Do **not** use `db` or `localhost`.  
Use the EasyPanel MySQL **internal hostname**, usually:

`$(PROJECT_NAME)_<mysql-service-name>`

Examples:
- project `dev`, MySQL service `mysql` → `dev_mysql`
- project `adserve`, MySQL service `database` → `adserve_database`

If logs show `getaddrinfo for db failed`, your app is still using the old default host `db` — set `DB_HOST` correctly in **Environment** and Redeploy.

**Required for auto-install**

| Variable | Required | Description |
| --- | --- | --- |
| `DB_HOST` | Yes* | EasyPanel MySQL internal hostname (not `db` / not `localhost`) |
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

### 4) Mounts / Volumes (**required for persistent data**)

EasyPanel does **not** create app volumes from the image automatically.  
Open **Mounts** → add **Volume** mounts (see also [`easypanel.mounts.txt`](./easypanel.mounts.txt) and [`docker-compose.yml`](./docker-compose.yml)):

| Volume name | Mount path | Stores |
| --- | --- | --- |
| `revive-var` | `/var/www/html/var` | Config, `INSTALLED`, cache, plugin data (**required**) |
| `revive-images` | `/var/www/html/www/images` | Uploaded banners/creatives (**required**) |
| `revive-plugins` | `/var/www/html/plugins` | Plugins (recommended) |
| `revive-admin-plugins` | `/var/www/html/www/admin/plugins` | Admin plugins (recommended) |

Without these, redeploy/restart can wipe install config and uploaded ads.

The image fixes ownership on start (`chmod a+rwX`). If System check still says `/var/www/html/var` is not writable, Redeploy after pulling latest `6.0.8`.

### 5) MySQL

Create a **MySQL** service in the same EasyPanel project (it has its own data volume).  
Create DB/user, then set `DB_HOST` / credentials above to match.  
Campaign and statistics data live in MySQL — keep that MySQL volume.

### What happens on Deploy

1. Container starts  
2. Creates `/var/www/html/.env` from `.env.example` if missing  
3. Loads EasyPanel env (overrides file values)  
4. If not installed yet and required vars are set → auto CLI install  
5. Apache serves the app → open `/www/admin` to log in  

---

## Docker Hub pull

```bash
docker pull openbun/revive-adserver:6.0.8
```

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
  openbun/revive-adserver:6.0.8
```

---

## Upstream Revive Adserver

Revive Adserver is an open source ad serving tool that enables publishers to serve ads, manage campaigns, track performance, and apply targeting rules.

Official download: https://www.revive-adserver.com/download/

License: GPLv2 or later — see `LICENSE.txt` / `COPYRIGHT.txt`.

This product uses GeoLite2 data created by MaxMind: https://www.maxmind.com/
