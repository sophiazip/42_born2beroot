#!/usr/bin/env bash
set -euo pipefail

# Cria uma ISO de instalação personalizada sem alterar a imagem original.

show_usage() {
    cat >&2 <<'EOF'
Uso: scripts/build-iso.sh <iso-netinst-debian.iso> <iso-de-saida.iso>
EOF
    exit 2
}

require_commands() {
    local command

    for command in xorriso openssl sha256sum realpath; do
        if ! command -v "$command" >/dev/null 2>&1; then
            printf 'Dependência ausente: %s\n' "$command" >&2
            exit 1
        fi
    done
}

validate_iso_paths() {
    source_iso=$(realpath "$1")
    output_iso=$(realpath -m "$2")

    if [[ ! -f "$source_iso" ]]; then
        printf 'ISO de entrada não encontrada: %s\n' "$source_iso" >&2
        exit 1
    fi

    if [[ "$source_iso" == "$output_iso" ]]; then
        echo 'A ISO de entrada e a ISO de saída devem ser diferentes.' >&2
        exit 1
    fi
}

prompt_login() {
    read -r -p 'Login da 42 (sem o sufixo 42 do hostname): ' login

    if [[ ! "$login" =~ ^[a-z_][a-z0-9_-]{0,30}$ ]]; then
        echo 'Login inválido: use letras minúsculas, números, _ ou -.' >&2
        exit 1
    fi

    hostname="${login}42"
}

validate_password() {
    local password=$1
    local account_label=$2

    if [[ ${#password} -lt 10 || ! "$password" =~ [A-Z] || ! "$password" =~ [a-z] || ! "$password" =~ [0-9] ]]; then
        printf 'A senha de %s precisa ter 10 caracteres ou mais, com maiúscula, minúscula e número.\n' "$account_label" >&2
        return 1
    fi

    if [[ "$password" =~ (.)\1\1\1 ]]; then
        printf 'A senha de %s não pode repetir um caractere 4 vezes seguidas.\n' "$account_label" >&2
        return 1
    fi

    if [[ "$password" == *"$login"* ]]; then
        printf 'A senha de %s não pode conter o login.\n' "$account_label" >&2
        return 1
    fi
}

prompt_passwords() {
    local root_password
    local user_password

    read -r -s -p 'Senha do root: ' root_password
    printf '\n'
    read -r -s -p "Senha de ${login}: " user_password
    printf '\n'

    validate_password "$root_password" 'root'
    validate_password "$user_password" 'usuário'

    # O preseed precisa de hashes; as senhas em texto puro não são gravadas nele.
    root_hash=$(printf '%s' "$root_password" | openssl passwd -6 -stdin)
    user_hash=$(printf '%s' "$user_password" | openssl passwd -6 -stdin)
    unset root_password user_password
}

write_preseed() {
    cat > "$tmpdir/preseed.cfg" <<EOF
# Preseed gerado para a instalação Born2beRoot.
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
}

build_iso() {
    local script_dir

    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
    cp "$script_dir/late-install.sh" "$tmpdir/late-install.sh"
    cp "$script_dir/monitoring.sh" "$tmpdir/monitoring.sh"
    chmod 0755 "$tmpdir/late-install.sh" "$tmpdir/monitoring.sh"
    write_preseed

    # replay preserva os parâmetros de boot BIOS e UEFI da ISO original.
    xorriso -indev "$source_iso" -outdev "$output_iso" \
        -map "$tmpdir/preseed.cfg" /preseed.cfg \
        -map "$tmpdir/late-install.sh" /late-install.sh \
        -map "$tmpdir/monitoring.sh" /monitoring.sh \
        -boot_image any replay >/dev/null

    printf 'ISO criada: %s\n' "$output_iso"
    printf 'SHA-256: %s\n' "$(sha256sum "$output_iso" | cut -d ' ' -f1)"
}

main() {
    [[ $# -eq 2 ]] || show_usage

    require_commands
    validate_iso_paths "$1" "$2"
    prompt_login
    prompt_passwords
    build_iso

    cat <<'EOF'
Inicialize pela ISO e acrescente às opções do instalador:
  auto=true priority=critical preseed/file=/cdrom/preseed.cfg
Digite a senha do LVM criptografado quando o Debian Installer solicitar.
EOF
}

main "$@"
