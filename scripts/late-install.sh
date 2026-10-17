#!/usr/bin/env bash
set -euo pipefail
login=${1:?login argument required}
hostname=${2:?hostname argument required}

echo "$hostname" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t$hostname/" /etc/hosts
groupadd -f user42
usermod -aG user42,sudo "$login"

cat > /etc/ssh/sshd_config.d/42-security.conf <<'EOF'
Port 4242
PermitRootLogin no
PasswordAuthentication yes
EOF
systemctl enable ssh
systemctl restart ssh

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 4242/tcp
ufw --force enable
systemctl enable ufw

install -d -m 0750 /var/log/sudo
touch /var/log/sudo/sudo.log
chmod 0600 /var/log/sudo/sudo.log
cat > /etc/sudoers.d/42-security <<'EOF'
Defaults passwd_tries=3
Defaults badpass_message="Incorrect password. Please try again."
Defaults use_pty
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Defaults logfile="/var/log/sudo/sudo.log"
Defaults log_input,log_output
Defaults iolog_dir="/var/log/sudo"
EOF
chmod 0440 /etc/sudoers.d/42-security
visudo -cf /etc/sudoers >/dev/null

if ! grep -q 'pam_pwquality.so' /etc/pam.d/common-password; then
    sed -i '/^password\s\+\[success=1 default=ignore\]\+\s\+pam_unix.so/i password requisite pam_pwquality.so retry=3 minlen=10 ucredit=-1 lcredit=-1 dcredit=-1 maxrepeat=3 usercheck=1 difok=7' /etc/pam.d/common-password
fi
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t30/; s/^PASS_MIN_DAYS.*/PASS_MIN_DAYS\t2/; s/^PASS_WARN_AGE.*/PASS_WARN_AGE\t7/' /etc/login.defs
chage -M 30 -m 2 -W 7 "$login"
chage -M 30 -m 2 -W 7 root
chage -d 0 "$login"
chage -d 0 root

chmod 0755 /usr/local/sbin/monitoring.sh
cat > /etc/cron.d/42-monitoring <<'EOF'
@reboot root /usr/local/sbin/monitoring.sh | /usr/bin/wall
*/10 * * * * root /usr/local/sbin/monitoring.sh | /usr/bin/wall
EOF
chmod 0644 /etc/cron.d/42-monitoring
systemctl enable apparmor cron
rm -f /root/late-install.sh
