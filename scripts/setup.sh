#!/usr/bin/env bash
# Run as root inside the Ubuntu container.

set -euo pipefail

AGENT_HOME="/home/agent-admin/agent-app"
AGENT_LOG_DIR="/var/log/agent-app"
MISSION_DIR="/mission"

if [[ "$(id -u)" -ne 0 ]]; then
    printf '[ERROR] Run this script as root.\n' >&2
    exit 1
fi

printf '[1/9] Creating groups and users...\n'
groupadd -f agent-common
groupadd -f agent-core

for user in agent-admin agent-dev agent-test; do
    if ! id "$user" >/dev/null 2>&1; then
        useradd -m -s /bin/bash "$user"
    fi
done

usermod -aG agent-common,agent-core agent-admin
usermod -aG agent-common,agent-core agent-dev
usermod -aG agent-common agent-test

printf '[2/9] Creating directories...\n'
install -d -o agent-admin -g agent-admin -m 0750 "$AGENT_HOME"
install -d -o agent-admin -g agent-common -m 2770 "$AGENT_HOME/upload_files"
install -d -o agent-admin -g agent-core -m 2770 "$AGENT_HOME/api_keys"
install -d -o agent-admin -g agent-core -m 2770 "$AGENT_HOME/bin"
install -d -o agent-admin -g agent-core -m 2770 "$AGENT_LOG_DIR"

printf '[3/9] Applying ACL policy...\n'
setfacl -m u::rwx,g::rwx,o::--- "$AGENT_HOME/upload_files"
setfacl -m d:u::rwx,d:g::rwx,d:o::--- "$AGENT_HOME/upload_files"
setfacl -m u::rwx,g::rwx,o::--- "$AGENT_HOME/api_keys" "$AGENT_LOG_DIR"
setfacl -m d:u::rwx,d:g::rwx,d:o::--- "$AGENT_HOME/api_keys" "$AGENT_LOG_DIR"

printf '[4/9] Installing the correct application binary...\n'
case "$(uname -m)" in
    x86_64|amd64)
        APP_SOURCE="$MISSION_DIR/agent-app/agent-app-linux-x86"
        ;;
    aarch64|arm64)
        APP_SOURCE="$MISSION_DIR/agent-app/agent-app-linux-arm64"
        ;;
    *)
        printf '[ERROR] Unsupported architecture: %s\n' "$(uname -m)" >&2
        exit 1
        ;;
esac

install -o agent-admin -g agent-core -m 0750 "$APP_SOURCE" "$AGENT_HOME/agent-app"
install -o agent-dev -g agent-core -m 0750 "$MISSION_DIR/src/monitor.sh" "$AGENT_HOME/bin/monitor.sh"
install -o agent-dev -g agent-core -m 0750 "$MISSION_DIR/src/report.sh" "$AGENT_HOME/bin/report.sh"

printf '[5/9] Creating required key files...\n'
printf 'agent_api_key_test\n' > "$AGENT_HOME/api_keys/t_secret.key"
printf 'agent_api_key_test\n' > "$AGENT_HOME/api_keys/secret.key"
chown agent-admin:agent-core "$AGENT_HOME/api_keys/t_secret.key" "$AGENT_HOME/api_keys/secret.key"
chmod 0660 "$AGENT_HOME/api_keys/t_secret.key" "$AGENT_HOME/api_keys/secret.key"

printf '[6/9] Preparing log files and logrotate...\n'
touch "$AGENT_LOG_DIR/monitor.log" "$AGENT_LOG_DIR/cron.log" "$AGENT_LOG_DIR/agent-app.log"
chown agent-admin:agent-core "$AGENT_LOG_DIR"/*.log
chmod 0660 "$AGENT_LOG_DIR"/*.log
install -o root -g root -m 0644 "$MISSION_DIR/config/agent-app.logrotate" /etc/logrotate.d/agent-app
cat > /etc/cron.d/agent-logrotate <<'CRON'
*/5 * * * * root /usr/sbin/logrotate /etc/logrotate.d/agent-app >/dev/null 2>&1
CRON
chmod 0644 /etc/cron.d/agent-logrotate

printf '[7/9] Configuring SSH...\n'
mkdir -p /etc/ssh/sshd_config.d /run/sshd
cat > /etc/ssh/sshd_config.d/99-agent-mission.conf <<'SSHD'
Port 20022
PermitRootLogin no
PasswordAuthentication yes
SSHD
sshd -t
service ssh restart

cat > /etc/sudoers.d/agent-monitor-ufw <<'SUDOERS'
agent-admin ALL=(root) NOPASSWD: /usr/sbin/ufw status
SUDOERS
chmod 0440 /etc/sudoers.d/agent-monitor-ufw
visudo -cf /etc/sudoers.d/agent-monitor-ufw >/dev/null

printf '[8/9] Configuring UFW...\n'
ufw --force reset >/dev/null
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow 20022/tcp >/dev/null
ufw allow 15034/tcp >/dev/null
if ! ufw --force enable >/dev/null; then
    printf '[WARNING] UFW could not be enabled automatically. Check container privileges and run ufw --force enable manually.\n' >&2
fi

printf '[9/9] Registering agent-admin cron job...\n'
CRON_LINE='* * * * * /home/agent-admin/agent-app/bin/monitor.sh >> /var/log/agent-app/cron.log 2>&1'
printf '%s\n' "$CRON_LINE" | crontab -u agent-admin -
service cron restart

cat <<'INFO'

Setup complete.

Important binary compatibility note:
- The mission document names t_secret.key and describes AGENT_KEY_PATH as that file.
- The supplied binary actually validates AGENT_KEY_PATH as the api_keys directory
  and reads api_keys/secret.key.
- setup.sh creates both files. start-agent.sh uses the directory value required by
  the supplied binary.

Before testing SSH password login, set a password:
  passwd agent-admin

Start the application:
  /mission/scripts/start-agent.sh
INFO
