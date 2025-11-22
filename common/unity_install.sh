#!/system/bin/sh
# Unity Install Script for zRAM Manager
# Optimized version with better error handling

# Configuration file path
CONFIG_FILE="/data/adb/swap-config.txt"
SERVICE_TEMPLATE="${TMPDIR}/common/service.sh"

# Display separator
print_separator() {
    ui_print " "
}

# Load saved configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        CONFIG=$(cat "$CONFIG_FILE" 2>/dev/null)
        
        # Validate config value
        case "$CONFIG" in
            0|1) return 0 ;;
            *) CONFIG="" ;;
        esac
    fi
    
    return 1
}

# Save configuration
save_config() {
    local config="$1"
    
    # Remove old config
    rm -f "$CONFIG_FILE" 2>/dev/null
    
    # Save new config
    echo "$config" > "$CONFIG_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        ui_print "   Configuration saved successfully"
        return 0
    else
        ui_print "   Warning: Failed to save configuration"
        return 1
    fi
}

# Apply configuration to service script
apply_config_to_service() {
    local config="$1"
    
    if [ ! -f "$SERVICE_TEMPLATE" ]; then
        ui_print "   Error: Service script not found!"
        return 1
    fi
    
    # Replace placeholder with actual config value
    sed -i "s/<CONFIG>/${config}/g" "$SERVICE_TEMPLATE"
    
    if [ $? -eq 0 ]; then
        return 0
    else
        ui_print "   Error: Failed to apply configuration to service script"
        return 1
    fi
}

# Get user choice via volume keys
get_user_choice() {
    print_separator
    ui_print "** Please choose zRAM configuration **"
    print_separator
    ui_print "   Vol(+) = Enable zRAM (Recommended)"
    ui_print "   Vol(-) = Disable zRAM"
    print_separator
    
    # Small delay for user to read
    sleep 1
    
    # Use volume key selector
    if $VKSEL; then
        CONFIG=1
        ui_print "   ✓ User selected: Enable zRAM"
    else
        CONFIG=0
        ui_print "   ✓ User selected: Disable zRAM"
    fi
    
    print_separator
}

# Display current configuration
display_config() {
    local config="$1"
    
    case "$config" in
        1) ui_print "   Current configuration: Enable zRAM" ;;
        0) ui_print "   Current configuration: Disable zRAM" ;;
        *) ui_print "   Current configuration: Unknown" ;;
    esac
}

# Main installation logic
main() {
    print_separator
    
    # Try to load saved configuration
    if load_config && [ -n "$CONFIG" ]; then
        ui_print "   Using saved configuration"
        display_config "$CONFIG"
    else
        # No saved config, ask user
        get_user_choice
    fi
    
    print_separator
    
    # Validate configuration
    if [ -z "$CONFIG" ]; then
        ui_print "   Error: No configuration selected!"
        CONFIG=1  # Default to enable
        ui_print "   Defaulting to: Enable zRAM"
    fi
    
    # Apply configuration to service script
    if apply_config_to_service "$CONFIG"; then
        ui_print "   ✓ Configuration applied to service script"
    else
        ui_print "   ✗ Failed to configure service script"
        return 1
    fi
    
    # Save configuration for future use
    save_config "$CONFIG"
    
    print_separator
    ui_print "   Installation configuration complete!"
    print_separator
    
    # Brief pause for user to see the results
    sleep 1
    
    return 0
}

# Execute main function
main