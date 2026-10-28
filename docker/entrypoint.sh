#!/bin/bash
set -euo pipefail

APP_ROOT=/var/www/html
ENV_FILE="${APP_ROOT}/.env"
ENV_EXAMPLE="${APP_ROOT}/.env.example"
INSTALLER_CONF=/tmp/revive-installer.conf.php
MARKER="${APP_ROOT}/var/INSTALLED"

cd "$APP_ROOT"

# Create .env from example on first run (EasyPanel can also inject env vars directly)
if [[ ! -f "$ENV_FILE" && -f "$ENV_EXAMPLE" ]]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  chown www-data:www-data "$ENV_FILE" 2>/dev/null || true
  echo "[entrypoint] Created ${ENV_FILE} from .env.example — edit it or set env vars in EasyPanel"
fi

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

mkdir -p \
  "${APP_ROOT}/var/plugins/DataObjects" \
  "${APP_ROOT}/var/cache" \
  "${APP_ROOT}/var/templates_compiled" \
  "${APP_ROOT}/www/images"
chown -R www-data:www-data "${APP_ROOT}/var" "${APP_ROOT}/www/images" 2>/dev/null || true
chmod -R u+rwX "${APP_ROOT}/var" "${APP_ROOT}/www/images" 2>/dev/null || true

if [[ ! -f "$MARKER" && "${SKIP_AUTO_INSTALL:-0}" != "1" ]]; then
  if php "${APP_ROOT}/docker/generate-installer-conf.php" > "$INSTALLER_CONF" 2>/tmp/revive-env-err; then
    echo "[entrypoint] Generating installer config from env and running first-time install..."
    php "${APP_ROOT}/docker/cli-install.php" install -f "$INSTALLER_CONF"
    rm -f "$INSTALLER_CONF"
    echo "[entrypoint] Install finished"
  else
    echo "[entrypoint] Not installed yet. Set DB_* (or DATABASE_URL), ADMIN_PASSWORD, ADMIN_EMAIL in .env / EasyPanel to auto-install, or use the web installer."
    if [[ -s /tmp/revive-env-err ]]; then
      echo "[entrypoint] $(cat /tmp/revive-env-err)"
    fi
    rm -f "$INSTALLER_CONF"
  fi
fi

exec apache2-foreground
