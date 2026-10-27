#!/usr/bin/env bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
set -u

# Coleta os indicadores exigidos pelo subject e os envia para a saída padrão.

get_cpu_usage() {
    local before_idle before_total after_idle after_total total
    local _ user nice system idle iowait irq softirq steal

    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    before_idle=$((idle + iowait))
    before_total=$((user + nice + system + idle + iowait + irq + softirq + ${steal:-0}))

    # A utilização é calculada pela diferença entre duas amostras de /proc/stat.
    sleep 1
    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    after_idle=$((idle + iowait))
    after_total=$((user + nice + system + idle + iowait + irq + softirq + ${steal:-0}))
    total=$((after_total - before_total))

    if (( total > 0 )); then
        awk -v total="$total" -v idle="$((after_idle - before_idle))" \
            'BEGIN { printf "%.1f", 100 * (total - idle) / total }'
    else
        echo 0
    fi
}

get_physical_cpu_count() {
    awk '
        /^physical id/ { ids[$4] = 1 }
        END {
            for (id in ids) count++
            print count ? count : 1
        }
    ' /proc/cpuinfo
}

get_memory_usage() {
    awk '
        /^MemTotal:/     { total = $2 }
        /^MemAvailable:/ { avail = $2 }
        END {
            used = total - avail
            printf "%d/%dMB (%.2f%%)", used / 1024, total / 1024,
                   (total ? used * 100 / total : 0)
        }
    ' /proc/meminfo
}

get_disk_usage() {
    df -hP / | awk 'NR == 2 { printf "%s/%s (%s)", $3, $2, $5 }'
}

get_network_interface() {
    ip -o -4 route get 1.1.1.1 2>/dev/null |
        awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
}

get_ipv4_address() {
    ip -o -4 route get 1.1.1.1 2>/dev/null |
        awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }'
}

get_sudo_command_count() {
    if [[ -r /var/log/sudo/sudo.log ]]; then
        grep -c 'COMMAND=' /var/log/sudo/sudo.log || true
    else
        journalctl -q _COMM=sudo --no-pager 2>/dev/null | grep -c 'COMMAND=' || true
    fi
}

main() {
    local architecture physical_cpu virtual_cpu memory disk cpu last_boot
    local lvm connections logged_users interface ipv4 mac sudo_count

    architecture=$(uname -a)
    physical_cpu=$(get_physical_cpu_count)
    virtual_cpu=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
    memory=$(get_memory_usage)
    disk=$(get_disk_usage)
    cpu=$(get_cpu_usage)
    last_boot=$(uptime -s 2>/dev/null || who -b | awk '{ print $3, $4 }')

    # A presença de ao menos um volume lógico indica que LVM está em uso.
    if lsblk -o TYPE 2>/dev/null | grep -q '^lvm$'; then
        lvm=yes
    else
        lvm=no
    fi

    connections=$(ss -Htan state established 2>/dev/null | wc -l)
    logged_users=$(who | wc -l)
    interface=$(get_network_interface)
    ipv4=$(get_ipv4_address)
    mac=$(cat "/sys/class/net/${interface:-lo}/address" 2>/dev/null || echo unknown)
    sudo_count=$(get_sudo_command_count)

    message=$(cat <<EOF
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
#Network: IP ${ipv4:-unknown} ($mac)
#Sudo: $sudo_count cmd
EOF
)

    for tty_device in /dev/pts/[0-9]*; do
       if [ -w "$tty_device" ]; then
		echo -e "\nBroadcast Message from root...\n$message\n" > "$tty_device"
        fi
    done
}

main "$@"
