#!/system/bin/sh
# Volume Key Selector for zRAM Manager
# Optimized with better error handling and cleaner code

# Configuration file
CONFIG_FILE="/data/adb/swap-config.txt"

# Setup external tools
setup_tools() {
    if [ -d "$TMPDIR/addon/Volume-Key-Selector/tools" ]; then
        chmod -R 0755 "$TMPDIR/addon/Volume-Key-Selector/tools"
        cp -R "$TMPDIR/addon/Volume-Key-Selector/tools" "$UF" 2>/dev/null
    fi
}

# Test if volume keys work using getevent
keytest() {
    ui_print "- Testing Volume Keys -"
    ui_print "  Press any Volume key..."
    
    # Try to detect volume key press
    timeout 3 /system/bin/getevent -lc 1 2>&1 | \
        /system/bin/grep VOLUME | \
        /system/bin/grep " DOWN" > "$TMPDIR/events" 2>/dev/null
    
    [ -s "$TMPDIR/events" ] && return 0 || return 1
}

# Modern volume key detection using getevent
chooseport() {
    local timeout_count=0
    local max_timeout=30  # 30 second timeout
    
    while [ $timeout_count -lt $max_timeout ]; do
        # Wait for volume key press
        /system/bin/getevent -lc 1 2>&1 | \
            /system/bin/grep VOLUME | \
            /system/bin/grep " DOWN" > "$TMPDIR/events" 2>/dev/null
        
        # Check if we got a volume key event
        if grep -q VOLUME "$TMPDIR/events" 2>/dev/null; then
            # Check which key was pressed
            if grep -q VOLUMEUP "$TMPDIR/events" 2>/dev/null; then
                return 0  # Volume Up
            else
                return 1  # Volume Down
            fi
        fi
        
        timeout_count=$((timeout_count + 1))
        sleep 0.1
    done
    
    # Timeout - default to Volume Up (enable)
    ui_print "  Timeout - defaulting to Enable"
    return 0
}

# Legacy volume key detection using keycheck binary
chooseport_legacy() {
    # First call detects previous input, second call gets actual input
    keycheck >/dev/null 2>&1
    keycheck >/dev/null 2>&1
    local sel=$?
    
    case "$1" in
        UP)
            UP=$sel
            ;;
        DOWN)
            DOWN=$sel
            ;;
        *)
            [ $sel -eq $UP ] && return 0
            [ $sel -eq $DOWN ] && return 1
            abort "  Volume key not detected! Aborting!"
            ;;
    esac
}

# Load saved configuration
load_saved_config() {
    if [ -f "$CONFIG_FILE" ]; then
        CONFIG=$(cat "$CONFIG_FILE" 2>/dev/null)
        
        # Validate config
        case "$CONFIG" in
            0|1) return 0 ;;
            *) CONFIG="" ;;
        esac
    fi
    
    return 1
}

# Check if user wants to skip volume keys via filename
check_filename_override() {
    local zipname
    zipname=$(basename "$ZIPFILE" | tr '[:upper:]' '[:lower:]')
    
    case "$zipname" in
        *disable*)
            CONFIG=0
            ui_print "- Filename detected: Disable mode"
            ui_print "- Skipping Volume Key selection"
            return 0
            ;;
        *enable*)
            CONFIG=1
            ui_print "- Filename detected: Enable mode"
            ui_print "- Skipping Volume Key selection"
            return 0
            ;;
    esac
    
    return 1
}

# Main volume key selector logic
main() {
    # Setup tools directory
    setup_tools
    
    # Load saved configuration if exists
    load_saved_config
    
    # Check for filename override (disable.zip or enable.zip)
    [ -z "$PROFILEMODE" ] && check_filename_override && return 0
    
    # If no saved config and no filename override, use volume keys
    ui_print " "
    
    # Test if modern getevent method works
    if keytest; then
        VKSEL=chooseport
    else
        # Fallback to legacy keycheck method
        VKSEL=chooseport_legacy
        
        ui_print "  Legacy device detected - using keycheck method"
        ui_print " "
        ui_print "- Volume Key Programming -"
        ui_print "  Press Volume Up:"
        $VKSEL UP
        ui_print "  Press Volume Down:"
        $VKSEL DOWN
    fi
    
    return 0
}

# Execute main function
main