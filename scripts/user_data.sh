#!/bin/bash
set -euo pipefail

APP_USER="${app_user}"
APP_GROUP="${app_group}"
APP_DIR="${app_dir}"
SERVICE_NAME="${service_name}"
ENV_FILE="$APP_DIR/.env"

### ====== Configure log color ======
log()  { echo -e "\033[1;32m[OK]\033[0m $*"; }
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERR]\033[0m  $*" >&2; }

info "=== Setting up environment for web app in $APP_DIR ==="

mkdir -p "$APP_DIR" # make sure the directory exist

cat >> "$ENV_FILE" <<EOF
DB_HOST='${db_host}'
DB_PORT='${db_port}'
DB_NAME='${db_name}'
DB_USER='${db_username}'
DB_PASSWORD='${db_password}'
EOF

chown "$APP_USER:$APP_GROUP" "$ENV_FILE" # Change owner of the .env file to normal user
chmod 600 "$ENV_FILE" # only rw for owner (not even root can see this file)

systemctl daemon-reload # let systemd reload all the .service file
systemctl enable "${SERVICE_NAME}.service"
systemctl restart "${SERVICE_NAME}.service"

info "=== Web App started successfully ==="
