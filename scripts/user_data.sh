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
SNS_TOPIC_ARN=${sns_topic_arn}
EOF

chown "${app_user}:${app_group}" "$ENV_FILE" # Change owner of the .env file to normal user
chmod 600 "$ENV_FILE" # only rw for owner (not even root can see this file)

systemctl daemon-reload # let systemd reload all the .service file
systemctl enable "${service_name}.service"
systemctl restart "${service_name}.service"

# Wait for the service to be active
info "Waiting for ${service_name} to start..."
sleep 5

# Verify the service is running
if systemctl is-active --quiet "${service_name}.service"; then
  log "${service_name} service is active"
else
  err "${service_name} service failed to start"
  systemctl status "${service_name}.service" --no-pager
  exit 1
fi

# Wait for the application to be ready to accept connections
# Check if the app is listening on the configured app_port
info "Waiting for application to be ready on port ${app_port}..."
MAX_WAIT=120
WAIT_COUNT=0
while [ $$WAIT_COUNT -lt $$MAX_WAIT ]; do
  if netstat -tln 2>/dev/null | grep -q ":${app_port} " || ss -tln 2>/dev/null | grep -q ":${app_port} "; then
    log "Application is listening on port ${app_port}"
    break
  fi
  sleep 2
  WAIT_COUNT=$$((WAIT_COUNT + 2))
  if [ $$((WAIT_COUNT % 10)) -eq 0 ]; then
    info "Still waiting for application to start... ($${WAIT_COUNT}s elapsed)"
  fi
done

if [ $$WAIT_COUNT -ge $$MAX_WAIT ]; then
  err "Application did not start listening on port ${app_port} within $${MAX_WAIT} seconds"
  systemctl status "${service_name}.service" --no-pager
  journalctl -u "${service_name}.service" -n 50 --no-pager
  exit 1
fi

info "=== Web App started successfully ==="

# ---------------------------------------------------------------------------
# CloudWatch Agent: Refresh and start using baked config (from Packer)
# ---------------------------------------------------------------------------
CWA_BIN="/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"
CWA_CFG="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"

info "=== Preparing CloudWatch Agent ==="

# Ensure application log directory exists (for ${app_dir}/log/app.log)
install -d -m 0755 -o "${app_user}" -g "${app_group}" "${app_dir}/log" || true

if [ -x "$CWA_BIN" ] && [ -f "$CWA_CFG" ]; then
  info "CloudWatch Agent binary and config found. Enabling and refreshing..."
  
  # Enable on boot (idempotent)
  systemctl enable amazon-cloudwatch-agent || true

  # Stop agent if running (safe if it's not)
  "$CWA_BIN" -a stop || true

  # Fetch baked config and start
  "$CWA_BIN" -a fetch-config -m ec2 -c file:"$CWA_CFG" -s

  # Check service status (non-fatal)
  systemctl status amazon-cloudwatch-agent --no-pager || true

  info "CloudWatch Agent started with baked config."
else
  err "CloudWatch Agent binary or config not found. Skipping agent start."
fi

info "=== User data script completed successfully ==="
