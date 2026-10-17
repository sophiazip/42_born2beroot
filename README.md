*This project has been created as part of the 42 curriculum by eroque-d.*

# Born2beroot Debian ISO builder

## Description

This repository contains scripts that add a Debian Installer preseed and post-install configuration to an official Debian stable amd64 netinst ISO. The resulting installer configures an encrypted LVM installation, a 42 user, SSH on port 4242, UFW, AppArmor, password aging and quality rules, sudo logging, and the required monitoring report.

The ISO is only a starting point for the subject. It does not create a VirtualBox/UTM virtual machine, calculate or save the virtual disk signature, or replace understanding and checking each configured service. Debian Installer still asks for the disk encryption passphrase. Password hashes are generated from the passwords entered while building the ISO and are present in the ISO's preseed file; keep the generated ISO private and delete it securely when no longer needed.

## Instructions

### Requirements

- A Debian stable amd64 netinst ISO obtained from the [official Debian CD image site](https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/).
- `xorriso`, `openssl`, `sha256sum`, and `realpath` on the build host.
- A VM with a blank virtual disk (the partitioning recipe erases the selected disk), network access during installation, and at least 20 GB of disk space.

On Debian or Ubuntu, install the ISO tooling with `sudo apt install xorriso openssl coreutils`.

### Build the installer ISO

```sh
chmod +x scripts/*.sh
scripts/build-iso.sh debian-stable-amd64-netinst.iso born2beroot.iso
```

Enter your 42 login without the `42` hostname suffix, then choose strong root and user passwords when prompted. The script checks their length and character classes, then stores SHA-512 password hashes in the ISO. Use a private working directory and do not commit the generated ISO.

The installer expects the standard Debian amd64 netinst layout. Start the VM from the generated ISO. At the Debian Installer boot menu, edit the **Install** entry (press `e` in GRUB or `Tab` in the BIOS menu), append:

```text
auto=true priority=critical preseed/file=/cdrom/preseed.cfg
```

Boot that edited entry. The guided encrypted-LVM partitioning erases the VM disk. Enter the disk encryption passphrase when requested. The machine needs network access to install packages. Reboot from the virtual disk after installation and remove/eject the installer ISO.

The first console login for both root and the 42 user requires changing the password. Do this at the VM console before connecting over SSH; it applies the configured password quality and history checks to the new passwords. The user can then connect with `ssh -p 4242 <your-login>@<vm-ip>`.

### Included scripts

- `scripts/build-iso.sh` prompts for account details, generates a preseed, and adds it and the installation scripts to a bootable ISO with `xorriso`.
- `scripts/late-install.sh` configures SSH, UFW, sudo, PAM password quality, password aging, AppArmor, and cron in the installed system.
- `scripts/monitoring.sh` reports the mandatory system and resource information. Cron broadcasts it at boot and every ten minutes with `wall`.

## Project design

Debian stable is used because it is recommended by the subject and has a small, well documented server installation. Its broad package ecosystem and `apt` tools are convenient; its release cadence is slower than Rocky's and package versions prioritize stability. Rocky Linux follows Red Hat Enterprise Linux compatibility and commonly uses SELinux and `dnf`, which is useful in RHEL environments, but it was not selected for this Debian-focused setup.

The installer uses Debian's guided encrypted LVM layout, which provides encrypted logical volumes for the system and swap. SSH is the only inbound firewall port. No desktop environment is selected. The user is placed in `user42` and `sudo`; SSH root login is disabled. The machine is configured with AppArmor, UFW, and cron.

| Comparison | Debian setup | Alternative |
|---|---|---|
| Debian vs Rocky Linux | Debian stable, `apt`, AppArmor | Rocky Linux, `dnf`, SELinux; closer to RHEL administration |
| AppArmor vs SELinux | AppArmor confines applications with path-based profiles and is enabled here | SELinux applies label- and policy-based mandatory access controls; common on RHEL systems |
| UFW vs firewalld | UFW provides a simple host firewall interface and allows TCP 4242 | firewalld supports dynamic zones and service abstractions and is required by the Rocky path in the subject |
| VirtualBox vs UTM | Either can run this amd64 Debian VM; VirtualBox is the common cross-platform option | UTM is useful on Apple Silicon and uses QEMU virtualization/emulation |

## Resources

- Born2beRoot subject PDF supplied with the project environment (kept out of this Git repository)
- [Debian Installation Guide](https://www.debian.org/releases/stable/amd64/)
- [Debian preseed documentation](https://www.debian.org/releases/stable/amd64/apbs04.en.html)
- [Debian release information](https://www.debian.org/releases/)
- [OpenSSH server documentation](https://manpages.debian.org/openssh-server/sshd_config.5.en.html)
- [UFW manual](https://manpages.debian.org/ufw/ufw.8.en.html)
- [sudoers manual](https://manpages.debian.org/sudo/sudoers.5.en.html)

AI was used to draft and organize these scripts and this documentation from the subject's requirements. Review the configuration and be ready to explain each setting during evaluation; the ISO output and VM installation must be verified by the student.
