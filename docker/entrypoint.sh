#!/bin/bash
set -euo pipefail

APP_ROOT=/var/www/html
ENV_FILE="${APP_ROOT}/.env"
ENV_EXAMPLE="${APP_ROOT}/.env.example"
INSTALLER_CONF=/tmp/revive-installer.conf.php
MARKER="${APP_ROOT}/var/INSTALLED"

cd "$APP_ROOT"

upsert_env_key() {
  local key="$1"
  local val="$2"
  local tmp
  tmp="$(mktemp)"
  if [[ -f "$ENV_FILE" ]] && grep -qE "^${key}=" "$ENV_FILE"; then
    awk -v k="$key" -v v="$val" 'BEGIN{FS=OFS="="} $1==k {$0=k"="v} {print}' "$ENV_FILE" > "$tmp"
    mv "$tmp" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
  fi
}

# Create .env from example on first run
if [[ ! -f "$ENV_FILE" && -f "$ENV_EXAMPLE" ]]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  chown www-data:www-data "$ENV_FILE" 2>/dev/null || true
  echo "[entrypoint] Created ${ENV_FILE} from .env.example"
fi

# Write EasyPanel/process env into .env so the file shows real values
for key in \
  DATABASE_URL DB_TYPE DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD DB_TABLE_PREFIX DB_TABLE_TYPE \
  ADMIN_USERNAME ADMIN_PASSWORD ADMIN_EMAIL ADMIN_LANGUAGE ADMIN_TIMEZONE \
  APP_HOSTNAME WEBPATH_ADMIN WEBPATH_DELIVERY WEBPATH_IMAGES REQUIRE_SSL SKIP_AUTO_INSTALL
do
  if [[ -n "${!key:-}" ]]; then
    upsert_env_key "$key" "${!key}"
  fi
done

# Load .env without overriding vars already set by the platform
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    key="$(echo "$key" | xargs)"
    [[ -z "$key" ]] && continue
    if [[ -z "${!key+x}" ]]; then
      export "$key=$val"
    fi
  done < "$ENV_FILE"
fi

# EasyPanel volume mounts often replace /var with root-owned empty dirs.
# Revive requires these paths writable by the web user (www-data).
fix_writable_dirs() {
  local dirs=(
    "${APP_ROOT}/var"
    "${APP_ROOT}/var/plugins"
    "${APP_ROOT}/var/plugins/DataObjects"
    "${APP_ROOT}/var/cache"
    "${APP_ROOT}/var/templates_compiled"
    "${APP_ROOT}/plugins"
    "${APP_ROOT}/www/admin/plugins"
    "${APP_ROOT}/www/images"
  )
  mkdir -p "${dirs[@]}"
  chown -R www-data:www-data "${dirs[@]}" 2>/dev/null || true
  # a+rwX matches Revive installer guidance and works when chown is restricted
  chmod -R a+rwX "${dirs[@]}" 2>/dev/null || true
  if ! su -s /bin/sh www-data -c "test -w '${APP_ROOT}/var'"; then
    echo "[entrypoint] WARNING: ${APP_ROOT}/var not writable by www-data — applying 0777"
    chmod -R 0777 "${APP_ROOT}/var" "${APP_ROOT}/plugins" "${APP_ROOT}/www/admin/plugins" "${APP_ROOT}/www/images" 2>/dev/null || true
  fi
  if su -s /bin/sh www-data -c "test -w '${APP_ROOT}/var'"; then
    echo "[entrypoint] Writable check OK: ${APP_ROOT}/var"
  else
    echo "[entrypoint] ERROR: ${APP_ROOT}/var still not writable. In EasyPanel, ensure the volume for /var/www/html/var is writable."
  fi
}

fix_writable_dirs

echo "[entrypoint] DB_HOST=${DB_HOST:-<empty>} DB_NAME=${DB_NAME:-<empty>} DB_USER=${DB_USER:-<empty>} APP_HOSTNAME=${APP_HOSTNAME:-<empty>}"

if [[ ! -f "$MARKER" && "${SKIP_AUTO_INSTALL:-0}" != "1" ]]; then
  if php "${APP_ROOT}/docker/generate-installer-conf.php" > "$INSTALLER_CONF" 2>/tmp/revive-env-err; then
    echo "[entrypoint] Running first-time install..."

    # Wait briefly for MySQL DNS/ readiness (EasyPanel services can start in parallel)
    if [[ -n "${DB_HOST:-}" ]]; then
      echo "[entrypoint] Waiting for database host '${DB_HOST}'..."
      for i in $(seq 1 30); do
        if php -r '$h=getenv("DB_HOST"); $p=(int)(getenv("DB_PORT")?:3306); $e=@fsockopen($h,$p,$errno,$errstr,2); if($e){fclose($e); exit(0);} exit(1);'; then
          echo "[entrypoint] Database port is reachable"
          break
        fi
        sleep 2
        if [[ "$i" -eq 30 ]]; then
          echo "[entrypoint] WARNING: could not reach ${DB_HOST}:${DB_PORT:-3306} after 60s — install may fail"
        fi
      done
    fi

    set +e
    php "${APP_ROOT}/docker/cli-install.php" install -f "$INSTALLER_CONF"
    install_rc=$?
    set -e
    rm -f "$INSTALLER_CONF"

    if [[ "$install_rc" -ne 0 ]]; then
      echo "[entrypoint] Auto-install FAILED (exit ${install_rc})."
      echo "[entrypoint] Your DB_HOST is '${DB_HOST:-<empty>}'."
      echo "[entrypoint] Fix EasyPanel → Environment:"
      echo "[entrypoint]   DB_HOST must be your MySQL service internal hostname"
      echo "[entrypoint]   Example: myproject_mysql   (NOT 'db', NOT localhost)"
      echo "[entrypoint]   Also set DB_NAME, DB_USER, DB_PASSWORD, ADMIN_PASSWORD, ADMIN_EMAIL"
      echo "[entrypoint] Starting Apache anyway so you can fix env and redeploy, or use /www/admin/install.php"
    else
      echo "[entrypoint] Install finished"
    fi
  else
    echo "[entrypoint] Not installed yet — missing required env for auto-install."
    if [[ -s /tmp/revive-env-err ]]; then
      echo "[entrypoint] $(cat /tmp/revive-env-err)"
    fi
    echo "[entrypoint] Set DB_HOST/DB_NAME/DB_USER/DB_PASSWORD (or DATABASE_URL), ADMIN_PASSWORD, ADMIN_EMAIL in EasyPanel Environment."
    rm -f "$INSTALLER_CONF"
  fi
fi

exec apache2-foreground
