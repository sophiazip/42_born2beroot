#!/usr/bin/env bash
set -u

cpu_sample() {
    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    before_idle=$((idle + iowait))
    before_total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    sleep 1
    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    after_idle=$((idle + iowait))
    after_total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    total=$((after_total - before_total))
    (( total > 0 )) && awk -v t="$total" -v i="$((after_idle - before_idle))" 'BEGIN { printf "%.1f", 100 * (t-i) / t }' || echo 0
}

architecture=$(uname -a)
physical_cpu=$(awk '/^physical id/ { ids[$4]=1 } END { print length(ids) ? length(ids) : 1 }' /proc/cpuinfo)
virtual_cpu=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
memory=$(free -m | awk '/^Mem:/ { used=$3; total=$2; printf "%d/%dMB (%.2f%%)", used, total, (total ? used*100/total : 0) }')
disk=$(df -hP / | awk 'NR==2 { printf "%s/%s (%s)", $3, $2, $5 }')
cpu=$(cpu_sample)
last_boot=$(uptime -s 2>/dev/null || who -b | awk '{print $3, $4}')
lvm=$(lsblk -o TYPE 2>/dev/null | grep -q '^lvm$' && echo yes || echo no)
connections=$(ss -Htan state established 2>/dev/null | wc -l)
logged_users=$(who | wc -l)
network=$(ip -o -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
interface=$(ip -o -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
mac=$(cat "/sys/class/net/${interface:-lo}/address" 2>/dev/null || echo unknown)
sudo_count=$(if [[ -f /var/log/sudo/sudo.log ]]; then grep -c 'COMMAND=' /var/log/sudo/sudo.log || true; else journalctl -q _COMM=sudo --no-pager 2>/dev/null | wc -l; fi)

cat <<EOF
#Architecture: $architecture
#Physical CPU: $physical_cpu
#vCPU: $virtual_cpu
#Memory Usage: $memory
#Disk Usage: $disk
#CPU load: ${cpu}%
#Last boot: $last_boot
#LVM use: $lvm
#TCP Connections: $connections ESTABLISHED
#User log: $logged_users
#Network: IP ${network:-unknown} ($mac)
#Sudo: $sudo_count cmd
EOF
