#!/system/bin/sh
# zRAM Manager Uninstall Script
# Optimized with better error handling

# Configuration file
CONFIG_FILE="/data/adb/swap-config.txt"

# Remount system partitions as read-write if needed
remount_rw() {
    if $SYSOVER || $DIRSEPOL; then
        mount -o rw,remount /system 2>/dev/null
        [ -L /system/vendor ] && mount -o rw,remount /vendor 2>/dev/null
    fi
}

# Remount system partitions as read-only
remount_ro() {
    if $SYSOVER || $DIRSEPOL; then
        mount -o ro,remount /system 2>/dev/null
        [ -L /system/vendor ] && mount -o ro,remount /vendor 2>/dev/null
    fi
}

# Remove a file safely
safe_remove() {
    local file="$1"
    
    if [ -f "$file" ]; then
        rm -f "$file" 2>/dev/null
        return $?
    fi
    
    return 0
}

# Restore backup file
restore_backup() {
    local file="$1"
    local backup="${file}~"
    
    if [ -f "$backup" ]; then
        mv -f "$backup" "$file" 2>/dev/null
        return $?
    fi
    
    return 1
}

# Remove file and clean empty parent directories
remove_and_cleanup() {
    local file="$1"
    local dir
    
    # Remove the file
    safe_remove "$file"
    
    # Clean up empty parent directories
    dir=$(dirname "$file")
    while [ "$dir" != "/" ] && [ "$dir" != "/system" ]; do
        # Check if directory is empty
        if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
            rmdir "$dir" 2>/dev/null || break
        else
            break
        fi
        dir=$(dirname "$dir")
    done
}

# Process files from info file
process_files() {
    local info_file="$1"
    local line file_path
    
    [ ! -f "$info_file" ] && return 1
    
    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Check for special markers
        if echo "$line" | grep -q "~$"; then
            # Backup file marker - skip it
            continue
        elif echo "$line" | grep -q "NORESTORE$"; then
            # No restore marker - just remove the file
            file_path=$(echo "$line" | sed 's/NORESTORE$//')
            remove_and_cleanup "$file_path"
        else
            # Normal file - try to restore backup first
            if ! restore_backup "$line"; then
                # No backup exists, just remove the file
                remove_and_cleanup "$line"
            fi
        fi
    done < "$info_file"
}

# Clean up module-specific files
cleanup_module_files() {
    # Remove configuration file
    safe_remove "$CONFIG_FILE"
    
    # Remove any swap files created by fallback method
    if [ -d /data/system/swap ]; then
        rm -rf /data/system/swap 2>/dev/null
    fi
    
    # Remove log file if exists
    safe_remove /data/local/tmp/zram.log
    
    # Disable any active swap
    if command -v swapoff >/dev/null 2>&1; then
        swapoff -a 2>/dev/null
    fi
}

# Main uninstall logic
main() {
    local info_file="$INFO"
    
    ui_print " "
    ui_print "- Starting zRAM Manager uninstall..."
    
    # Remount partitions if needed
    remount_rw
    
    # Determine info file location
    if $BOOTMODE && [ -f "$MODULEROOT/$MODID/${MODID}-files" ]; then
        info_file="$MODULEROOT/$MODID/${MODID}-files"
    fi
    
    # Check if module is installed
    if ! $MAGISK && [ ! -f "$info_file" ]; then
        ui_print "   Module not found!"
        remount_ro
        return 1
    fi
    
    # Process files from info file
    if [ -f "$info_file" ]; then
        ui_print "   Removing installed files..."
        process_files "$info_file"
        safe_remove "$info_file"
    fi
    
    # Clean up module-specific files
    ui_print "   Cleaning up configuration..."
    cleanup_module_files
    
    # Remount partitions back to read-only
    remount_ro
    
    ui_print "   Uninstall completed successfully!"
    ui_print " "
    
    return 0
}

# Execute main function
main