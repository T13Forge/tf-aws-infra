#!/bin/bash
set -euo pipefail

ENV_FILE="${app_dir}/.env"
LOG_FILE="/var/log/user_data_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

### ====== Configure log color ======
log()  { echo -e "\033[1;32m[OK]\033[0m $*"; }
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERR]\033[0m  $*" >&2; }

info "=== Setting up environment for web app in ${app_dir} ==="

mkdir -p "${app_dir}" # make sure the directory exist

cat >> "$ENV_FILE" <<EOF
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USERNAME=${db_username}
DB_PASSWORD=${db_password}
AWS_REGION=${aws_region}
S3_BUCKET=${s3_bucket}
EOF

chown "${app_user}:${app_group}" "$ENV_FILE" # Change owner of the .env file to normal user
chmod 600 "$ENV_FILE" # only rw for owner (not even root can see this file)

systemctl daemon-reload # let systemd reload all the .service file
systemctl enable "${service_name}.service"
systemctl restart "${service_name}.service"

info "=== Web App started successfully ==="
