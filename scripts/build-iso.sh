#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 <debian-netinst.iso> <output.iso>" >&2; exit 2; }
for command in xorriso openssl sha256sum; do command -v "$command" >/dev/null || { echo "Missing dependency: $command" >&2; exit 1; }; done
source_iso=$(realpath "$1"); output_iso=$(realpath -m "$2")
[[ -f "$source_iso" && "$source_iso" != "$output_iso" ]] || { echo "Invalid input/output ISO path." >&2; exit 1; }
read -r -p '42 login (without suffix 42): ' login
[[ "$login" =~ ^[a-z_][a-z0-9_-]{0,30}$ ]] || { echo "Invalid Unix login." >&2; exit 1; }
hostname="${login}42"
read -r -s -p 'Root password: ' root_password; echo
read -r -s -p "$login password: " user_password; echo
validate_password() {
    local password=$1 label=$2
    [[ ${#password} -ge 10 && "$password" =~ [A-Z] && "$password" =~ [a-z] && "$password" =~ [0-9] ]] || { echo "$label password needs 10+ chars with uppercase, lowercase, and a digit." >&2; return 1; }
    [[ ! "$password" =~ (.)\1\1\1 ]] || { echo "$label password cannot repeat a character more than 3 times consecutively." >&2; return 1; }
    [[ "$password" != *"$login"* ]] || { echo "$label password cannot contain the login." >&2; return 1; }
}
validate_password "$root_password" Root || exit 1
validate_password "$user_password" User || exit 1
root_hash=$(printf '%s' "$root_password" | openssl passwd -6 -stdin)
user_hash=$(printf '%s' "$user_password" | openssl passwd -6 -stdin)
unset root_password user_password
tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' EXIT
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
cp "$script_dir/late-install.sh" "$tmpdir/late-install.sh"
cp "$script_dir/monitoring.sh" "$tmpdir/monitoring.sh"
chmod 755 "$tmpdir/late-install.sh" "$tmpdir/monitoring.sh"
cat > "$tmpdir/preseed.cfg" <<EOF
# Generated Born2beroot installer configuration.
d-i debian-installer/locale string en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string $hostname
d-i netcfg/get_domain string local
d-i hw-detect/load_firmware boolean true
d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string
d-i passwd/root-login boolean true
d-i passwd/root-password-crypted password $root_hash
d-i passwd/make-user boolean true
d-i passwd/user-fullname string $login
d-i passwd/username string $login
d-i passwd/user-password-crypted password $user_hash
d-i clock-setup/utc boolean true
d-i time/zone string Etc/UTC
d-i partman-auto/method string crypto
d-i partman-auto/choose_recipe select atomic
d-i partman-auto-lvm/guided_size string max
d-i partman-crypto/confirm boolean true
d-i partman-crypto/confirm_nooverwrite boolean true
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman/mount_style select uuid
d-i base-installer/install-recommends boolean false
d-i apt-setup/cdrom/set-first boolean false
tasksel tasksel/first multiselect standard, ssh-server
d-i pkgsel/include string sudo ufw apparmor apparmor-profiles apparmor-utils libpam-pwquality openssh-server cron curl
d-i pkgsel/upgrade select safe-upgrade
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i finish-install/reboot_in_progress note
d-i preseed/late_command string cp /cdrom/late-install.sh /target/root/late-install.sh; cp /cdrom/monitoring.sh /target/usr/local/sbin/monitoring.sh; in-target /bin/bash /root/late-install.sh '$login' '$hostname'
EOF
xorriso -indev "$source_iso" -outdev "$output_iso" \
    -map "$tmpdir/preseed.cfg" /preseed.cfg \
    -map "$tmpdir/late-install.sh" /late-install.sh \
    -map "$tmpdir/monitoring.sh" /monitoring.sh \
    -boot_image any replay >/dev/null
echo "Created: $output_iso"
echo "SHA-256: $(sha256sum "$output_iso" | cut -d ' ' -f1)"
echo 'Boot and append: auto=true priority=critical preseed/file=/cdrom/preseed.cfg'
echo 'Enter the encrypted-LVM passphrase when Debian Installer prompts.'
