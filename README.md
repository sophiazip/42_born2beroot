<p align="center">
  <i>This project has been created as part of the 42 curriculum by eroque-d</i>
</p>
<h1 align="center">Born2beRoot</h1>
<p align="center">
  <strong>A small server, built to understand what runs beneath it</strong>
</p>

## Description

Born2beRoot introduces virtualization and system administration by setting up a
secure Linux server in VirtualBox or UTM. This repository provides scripts to
customize a Debian stable installer ISO and configure the mandatory services and
policies: encrypted LVM, SSH on port 4242, UFW, AppArmor, password rules, sudo
logging, and a monitoring report.

The scripts prepare the installer and configure the installed system; they do not
create the VM or virtual disk, produce the disk signature, or replace checking the
result and understanding each setting. Debian Installer still asks for the disk
encryption passphrase. Account password hashes are embedded in the generated ISO,
so keep it private and do not commit it.

## Build and usage

Install the tools on Debian or Ubuntu:

```sh
sudo apt install xorriso openssl coreutils
```

Get an official Debian stable amd64 netinst image from the
[Debian CD image site](https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/),
then build the customized installer:

```sh
scripts/build-iso.sh debian-stable-amd64-netinst.iso born2beroot.iso
```

The script asks for your 42 login (without the hostname suffix `42`), then root
and user passwords. It checks the password length and character classes and stores
SHA-512 hashes in the generated ISO. Do not commit that ISO. Use a VM with a blank
disk of at least 20 GB and network access; the guided encrypted-LVM setup erases
the selected disk.

Boot the VM from `born2beroot.iso`. At the Debian Installer boot menu, edit the
**Install** entry (`e` in GRUB or `Tab` in the BIOS menu) and append:

```text
auto=true priority=critical preseed/file=/cdrom/preseed.cfg
```

Boot the edited entry and enter the disk encryption passphrase when prompted. After
installation, boot from the virtual disk and eject the ISO. At the VM console, change
the initial root and user passwords when prompted; this applies the configured
password quality and history checks. Then connect with:

```sh
ssh -p 4242 <your-login>@<vm-ip>
```

> The installer requires network access to download packages. Only TCP port 4242 is
> opened for inbound connections by the configured firewall.

## Codebase structure

The setup follows this sequence:

1. `scripts/build-iso.sh` prompts for account details, generates a preseed, and adds
   it and the setup scripts to a bootable ISO with `xorriso`.
2. Debian Installer partitions the VM disk with encrypted LVM and installs the
   minimal Debian system and required packages.
3. `scripts/late-install.sh` configures the hostname and user groups, SSH, UFW,
   sudo, PAM password quality, password aging, AppArmor, and cron.
4. Cron runs `scripts/monitoring.sh` at boot and every ten minutes, broadcasting its
   report to logged-in terminals with `wall`.

## Source layout

```text
scripts/
├── build-iso.sh       creates a customized Debian installer ISO
├── late-install.sh    configures security and services in the installed system
└── monitoring.sh      reports system and resource usage
```

## Design choices

Debian stable is recommended by the subject and provides a minimal server install,
a broad package ecosystem, and straightforward `apt` administration. Its stable
release model favors tested package versions. Rocky Linux is closer to the Red Hat
Enterprise Linux ecosystem and commonly uses `dnf` and SELinux, but requires a
different setup and was not selected here.

The installer uses encrypted LVM for system storage and swap. SSH root login is
disabled, the 42 user belongs to `user42` and `sudo`, and UFW allows inbound SSH on
port 4242. No graphical desktop is installed. AppArmor is enabled at startup, and
cron handles the required periodic monitoring.

| Topic | Debian setup | Alternative |
|---|---|---|
| Debian vs Rocky Linux | Debian stable, `apt`, and AppArmor; simple server installation | Rocky Linux, `dnf`, and SELinux; familiar in RHEL environments |
| AppArmor vs SELinux | AppArmor confines applications with path-based profiles | SELinux uses labels and policy rules for mandatory access control |
| UFW vs firewalld | UFW provides a simple host firewall; only TCP 4242 is allowed inbound | firewalld provides zones and service abstractions; the subject requires it for Rocky |
| VirtualBox vs UTM | VirtualBox is a common cross-platform choice for the required VM | UTM uses QEMU and is useful on Apple Silicon, including emulation where needed |

## Resources

- Born2beRoot subject PDF supplied with the project environment (not included in this repository)
- [Debian Installation Guide](https://www.debian.org/releases/stable/amd64/)
- [Debian preseed documentation](https://www.debian.org/releases/stable/amd64/apbs04.en.html)
- [Debian release information](https://www.debian.org/releases/)
- [OpenSSH server configuration](https://manpages.debian.org/openssh-server/sshd_config.5.en.html)
- [UFW manual](https://manpages.debian.org/ufw/ufw.8.en.html)
- [sudoers manual](https://manpages.debian.org/sudo/sudoers.5.en.html)

### AI

AI assisted with drafting and organizing the scripts and documentation from the
subject requirements. I reviewed the configuration and checked the installed VM.
