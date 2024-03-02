#!/bin/bash

while true; do
    # Collect CPU information
    cpu_info=$(cat /proc/stat | grep '^cpu ')
    IFS=' ' read -ra cpu_data <<< "$cpu_info"
    user=${cpu_data[1]}
    nice=${cpu_data[2]}
    system=${cpu_data[3]}
    idle=${cpu_data[4]}
    iowait=${cpu_data[5]}
    irq=${cpu_data[6]}
    softirq=${cpu_data[7]}
    steal=${cpu_data[8]}

    # Collect memory information
    mem_info=$(cat /proc/meminfo)
    mem_total=$(echo "$mem_info" | grep '^MemTotal:' | awk '{print $2}')
    mem_free=$(echo "$mem_info" | grep '^MemFree:' | awk '{print $2}')
    mem_available=$(echo "$mem_info" | grep '^MemAvailable:' | awk '{print $2}')
    buffers=$(echo "$mem_info" | grep '^Buffers:' | awk '{print $2}')
    cached=$(echo "$mem_info" | grep '^Cached:' | awk '{print $2}')

    # Collect disk information
    disk_info=$(df -B1 --output=source,fstype,target,avail,size)
    disk_info=$(echo "$disk_info" | tail -n +2)

    # Generate HTML page in Prometheus format
    cat > /etc/nginx/mysite/metrics/index.html << EOF
# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} $idle
node_cpu_seconds_total{cpu="0",mode="iowait"} $iowait
node_cpu_seconds_total{cpu="0",mode="irq"} $irq
node_cpu_seconds_total{cpu="0",mode="nice"} $nice
node_cpu_seconds_total{cpu="0",mode="softirq"} $softirq
node_cpu_seconds_total{cpu="0",mode="steal"} $steal
node_cpu_seconds_total{cpu="0",mode="system"} $system
node_cpu_seconds_total{cpu="0",mode="user"} $user

# HELP node_memory_MemAvailable_bytes Memory information field MemAvailable_bytes.
# TYPE node_memory_MemAvailable_bytes gauge
node_memory_MemAvailable_bytes $mem_available
# HELP node_memory_MemFree_bytes Memory information field MemFree_bytes.
# TYPE node_memory_MemFree_bytes gauge
node_memory_MemFree_bytes $mem_free
# HELP node_memory_MemTotal_bytes Memory information field MemTotal_bytes.
# TYPE node_memory_MemTotal_bytes gauge
node_memory_MemTotal_bytes $mem_total
# HELP node_memory_Buffers_bytes Memory information field Buffers_bytes.
# TYPE node_memory_Buffers_bytes gauge
node_memory_Buffers_bytes $buffers
# HELP node_memory_Cached_bytes Memory information field Cached_bytes.
# TYPE node_memory_Cached_bytes gauge
node_memory_Cached_bytes $cached

EOF

    while read -r line; do
        IFS=' ' read -ra disk_data <<< "$line"
        device=${disk_data[0]}
        fstype=${disk_data[1]}
        mountpoint=${disk_data[2]}
        avail=${disk_data[3]}
        size=${disk_data[4]}

        cat >> /etc/nginx/mysite/metrics/index.html << EOF
# HELP node_filesystem_avail_bytes Filesystem space available to non-root users in bytes.
# TYPE node_filesystem_avail_bytes gauge
node_filesystem_avail_bytes{device="$device",fstype="$fstype",mountpoint="$mountpoint"} $avail

# HELP node_filesystem_size_bytes Filesystem size in bytes.
# TYPE node_filesystem_size_bytes gauge
node_filesystem_size_bytes{device="$device",fstype="$fstype",mountpoint="$mountpoint"} $size

EOF

    done <<< "$disk_info"

    sleep 3s # Refresh every 3 seconds
done

