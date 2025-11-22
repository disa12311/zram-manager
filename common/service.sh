#!/system/bin/sh
# zRAM/SWAP Manager Service Script
# Optimized for performance and reliability

# Logging function
log() {
    echo "[zRAM] $1" >> /data/local/tmp/zram.log
}

# Write to sysfs safely
write_sys() {
    local path="$1"
    local value="$2"
    
    if [ -f "$path" ]; then
        echo "$value" > "$path" 2>/dev/null && return 0
    fi
    log "Failed to write '$value' to '$path'"
    return 1
}

# Calculate optimal disk size based on total RAM
calc_disksize() {
    local total_ram=$1
    local disksize_mb
    
    if [ "$total_ram" -gt 3000000 ]; then
        disksize_mb=2048
    elif [ "$total_ram" -gt 2000000 ]; then
        disksize_mb=1792
    elif [ "$total_ram" -gt 1000000 ]; then
        disksize_mb=1024
    else
        disksize_mb=768
    fi
    
    echo "$disksize_mb"
}

# Find swap binary location
find_swap_bin() {
    local bin_name="$1"
    
    for path in "/system/bin" "/system/xbin"; do
        [ -f "$path/$bin_name" ] && echo "$path/$bin_name" && return 0
    done
    
    # Fallback to PATH
    command -v "$bin_name" 2>/dev/null && return 0
    return 1
}

# Reset zRAM device
zram_reset() {
    local device="$1"
    
    write_sys "/sys/block/$device/reset" 1
    write_sys "/sys/block/$device/disksize" 0
}

# Get best compression algorithm
get_best_algorithm() {
    local zram_dev="$1"
    local available_alg
    
    available_alg=$(cat "/sys/block/$zram_dev/comp_algorithm" 2>/dev/null)
    
    case "$available_alg" in
        *zstd*) echo "zstd" ;;
        *lz4*)  echo "lz4" ;;
        *lzo*)  echo "lzo" ;;
        *)      echo "lz4" ;;
    esac
}

# Enable swap
enable_swap() {
    local total_ram disksize_mb disksize zram zram_dev dev_index alg ram_dev
    
    log "Starting zRAM enable process..."
    
    # Get total RAM
    total_ram=$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null)
    [ -z "$total_ram" ] && { log "Failed to get total RAM"; return 1; }
    
    # Calculate disk size
    disksize_mb=$(calc_disksize "$total_ram")
    disksize=$((disksize_mb * 1024 * 1024))
    log "Calculated zRAM size: ${disksize_mb}MB for ${total_ram}KB RAM"
    
    # Find swap binaries
    SWON=$(find_swap_bin "swapon") || { log "swapon not found"; return 1; }
    SWOFF=$(find_swap_bin "swapoff") || { log "swapoff not found"; return 1; }
    
    # Remove existing swap devices
    log "Removing existing swap devices..."
    for zram in $(blkid | grep swap | awk -F'[/:]' '{print $4}'); do
        zram_dev="/dev/block/$zram"
        dev_index=$(echo "$zram" | grep -o "[0-9]*$")
        
        [ -n "$dev_index" ] && write_sys "/sys/class/zram-control/hot_remove" "$dev_index"
        "$SWOFF" "$zram_dev" 2>/dev/null
        zram_reset "$zram"
    done
    
    # Create new zRAM device
    if [ -e "/sys/class/zram-control/hot_add" ]; then
        ram_dev=$(cat /sys/class/zram-control/hot_add 2>/dev/null)
        [ -z "$ram_dev" ] && ram_dev=0
    else
        ram_dev=0
    fi
    
    zram="zram${ram_dev}"
    zram_dev="/dev/block/$zram"
    log "Using device: $zram_dev"
    
    # Configure zRAM
    alg=$(get_best_algorithm "$zram")
    log "Using compression algorithm: $alg"
    
    "$SWOFF" "$zram_dev" >/dev/null 2>&1
    
    write_sys "/sys/block/$zram/comp_algorithm" "$alg"
    write_sys "/sys/block/$zram/max_comp_streams" 8
    write_sys "/sys/block/$zram/reset" 1
    write_sys "/sys/block/$zram/disksize" "${disksize_mb}M"
    
    # Initialize device
    dd if=/dev/zero of="$zram_dev" bs=1M count="$disksize_mb" 2>/dev/null
    mkswap "$zram_dev" >/dev/null 2>&1
    "$SWON" "$zram_dev" >/dev/null 2>&1
    
    sleep 2
    
    # Verify swap is active
    swap_total=$(grep -i SwapTotal /proc/meminfo | awk '{print $2}')
    
    if [ "$swap_total" -eq 0 ]; then
        log "zRAM device creation failed, trying fallback method..."
        
        # Fallback: use loop device with file
        zram_dev="/dev/block/loop7"
        "$SWOFF" "$zram_dev" 2>/dev/null
        
        rm -rf /data/system/swap
        mkdir -p /data/system/swap
        
        if [ ! -f /data/system/swap/swapfile ]; then
            dd if=/dev/zero of=/data/system/swap/swapfile bs=1M count="$disksize_mb" 2>/dev/null
        fi
        
        losetup "$zram_dev" /data/system/swap/swapfile 2>/dev/null
        mkswap "$zram_dev" >/dev/null 2>&1
        "$SWON" "$zram_dev" >/dev/null 2>&1
        
        log "Fallback swap device created"
    fi
    
    # Set system properties
    setprop vnswap.enabled true
    setprop ro.config.zram true
    setprop ro.config.zram.support true
    setprop zram.disksize "$disksize"
    
    # Configure VM settings
    write_sys /proc/sys/vm/swappiness 100
    write_sys /proc/sys/vm/swap_ratio_enable 1 2>/dev/null
    write_sys /proc/sys/vm/swap_ratio 70 2>/dev/null
    
    log "zRAM enabled successfully"
    
    # Log final status
    swap_total=$(grep -i SwapTotal /proc/meminfo | awk '{print $2}')
    log "Active swap: ${swap_total}KB"
}

# Disable swap
disable_swap() {
    local zram zram_dev dev_index
    
    log "Starting zRAM disable process..."
    
    # Find swap binaries
    SWOFF=$(find_swap_bin "swapoff") || { log "swapoff not found"; return 1; }
    
    # Remove all swap devices
    for zram in $(blkid | grep swap | awk -F'[/:]' '{print $4}'); do
        zram_dev="/dev/block/$zram"
        dev_index=$(echo "$zram" | grep -o "[0-9]*$")
        
        [ -n "$dev_index" ] && write_sys "/sys/class/zram-control/hot_remove" "$dev_index"
        "$SWOFF" "$zram_dev" 2>/dev/null
        zram_reset "$zram"
    done
    
    # Clean up fallback swap if exists
    rm -rf /data/system/swap 2>/dev/null
    
    # Update system properties
    setprop vnswap.enabled false
    setprop ro.config.zram false
    setprop ro.config.zram.support false
    setprop zram.disksize 0
    
    # Reset VM settings
    write_sys /proc/sys/vm/swappiness 0
    
    log "zRAM disabled successfully"
}

# Main execution
main() {
    # Wait for system to stabilize
    sleep 30
    
    # Get configuration
    CONFIG=<CONFIG>
    
    log "=== zRAM Manager Service Started ==="
    log "Configuration: $CONFIG (0=disable, 1=enable)"
    
    if [ "$CONFIG" -eq 0 ]; then
        disable_swap
    else
        enable_swap
    fi
    
    log "=== Service execution completed ==="
}

# Run main function
main