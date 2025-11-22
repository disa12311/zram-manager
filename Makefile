# Makefile for zRAM/SWAP Manager (Magisk Module)
# Optimized for Android Magisk module build and deployment

# Project metadata
MODULE_ID = zram_config
MODULE_NAME = "zRAM/SWAP Manager"
VERSION = $(shell grep -oP '(?<=version=)[^\s]*' module.prop || echo "v1.3")
VERSION_CODE = $(shell grep -oP '(?<=versionCode=)[^\s]*' module.prop || echo "130")

# Build directories
BUILD_DIR = build
DIST_DIR = dist
RELEASE_DIR = release

# ZIP tools
ZIP = zip
UNZIP = unzip

# Colors
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
CYAN = \033[0;36m
NC = \033[0m

# Module files
MODULE_FILES = module.prop install.sh uninstall.sh
META_FILES = META-INF/com/google/android/update-binary META-INF/com/google/android/updater-script
COMMON_FILES = common/service.sh common/unity_install.sh common/unity_uninstall.sh common/unity_upgrade.sh
ADDON_FILES = addon/Volume-Key-Selector/preinstall.sh
UNITY_FILES = common/unityfiles/addon.sh common/unityfiles/util_functions.sh

.PHONY: all help clean build dist release test check lint format install-adb push-device

# Default target
all: build

help:
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  $(MODULE_NAME) - Magisk Module Build System$(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Building:$(NC)"
	@echo "  make build          - Build Magisk flashable ZIP"
	@echo "  make dist           - Create distribution package"
	@echo "  make release        - Create release with all variants"
	@echo "  make clean          - Remove build artifacts"
	@echo ""
	@echo "$(YELLOW)Testing:$(NC)"
	@echo "  make test           - Run basic tests"
	@echo "  make check          - Check shell scripts with shellcheck"
	@echo "  make lint           - Run all code quality checks"
	@echo "  make format         - Format shell scripts"
	@echo ""
	@echo "$(YELLOW)Deployment:$(NC)"
	@echo "  make install-adb    - Install to device via ADB"
	@echo "  make push-device    - Push module to device storage"
	@echo "  make uninstall-adb  - Uninstall from device via ADB"
	@echo ""
	@echo "$(YELLOW)Info:$(NC)"
	@echo "  Module ID:      $(MODULE_ID)"
	@echo "  Version:        $(VERSION)"
	@echo "  Version Code:   $(VERSION_CODE)"
	@echo ""

# Build the Magisk module ZIP
build: clean check
	@echo "$(GREEN)→ Building Magisk module ZIP...$(NC)"
	@mkdir -p $(BUILD_DIR)
	@echo "$(CYAN)  Creating directory structure...$(NC)"
	@mkdir -p $(BUILD_DIR)/META-INF/com/google/android
	@mkdir -p $(BUILD_DIR)/common/unityfiles
	@mkdir -p $(BUILD_DIR)/addon/Volume-Key-Selector
	
	@echo "$(CYAN)  Copying module files...$(NC)"
	@cp -f $(MODULE_FILES) $(BUILD_DIR)/
	@cp -f $(META_FILES) $(BUILD_DIR)/META-INF/com/google/android/
	@cp -f $(COMMON_FILES) $(BUILD_DIR)/common/ 2>/dev/null || true
	@cp -f $(ADDON_FILES) $(BUILD_DIR)/addon/Volume-Key-Selector/ 2>/dev/null || true
	@cp -f $(UNITY_FILES) $(BUILD_DIR)/common/unityfiles/ 2>/dev/null || true
	@cp -f LICENSE README.md $(BUILD_DIR)/ 2>/dev/null || true
	
	@echo "$(CYAN)  Setting permissions...$(NC)"
	@find $(BUILD_DIR) -type f -name "*.sh" -exec chmod 755 {} \;
	@chmod 755 $(BUILD_DIR)/META-INF/com/google/android/update-binary
	
	@echo "$(CYAN)  Creating ZIP package...$(NC)"
	@cd $(BUILD_DIR) && $(ZIP) -r9 ../$(MODULE_ID)-$(VERSION).zip . -x "*.git*" "*.DS_Store"
	@echo "$(GREEN)✓ Build complete: $(MODULE_ID)-$(VERSION).zip$(NC)"

# Create distribution package
dist: build
	@echo "$(GREEN)→ Creating distribution package...$(NC)"
	@mkdir -p $(DIST_DIR)
	@mv -f $(MODULE_ID)-$(VERSION).zip $(DIST_DIR)/
	@cd $(DIST_DIR) && sha256sum $(MODULE_ID)-$(VERSION).zip > $(MODULE_ID)-$(VERSION).zip.sha256
	@echo "$(GREEN)✓ Distribution package created in $(DIST_DIR)/$(NC)"
	@ls -lh $(DIST_DIR)

# Create release with variants
release: clean check
	@echo "$(GREEN)→ Creating release packages...$(NC)"
	@mkdir -p $(RELEASE_DIR)
	
	@echo "$(CYAN)  Building standard version...$(NC)"
	@$(MAKE) build
	@mv $(MODULE_ID)-$(VERSION).zip $(RELEASE_DIR)/$(MODULE_ID)-$(VERSION).zip
	
	@echo "$(CYAN)  Building enable variant...$(NC)"
	@$(MAKE) build
	@mv $(MODULE_ID)-$(VERSION).zip $(RELEASE_DIR)/$(MODULE_ID)-$(VERSION)-enable.zip
	
	@echo "$(CYAN)  Building disable variant...$(NC)"
	@$(MAKE) build
	@mv $(MODULE_ID)-$(VERSION).zip $(RELEASE_DIR)/$(MODULE_ID)-$(VERSION)-disable.zip
	
	@echo "$(CYAN)  Creating checksums...$(NC)"
	@cd $(RELEASE_DIR) && sha256sum *.zip > checksums.sha256
	
	@echo "$(GREEN)✓ Release packages created in $(RELEASE_DIR)/$(NC)"
	@ls -lh $(RELEASE_DIR)

# Code quality checks
check:
	@echo "$(GREEN)→ Running shellcheck...$(NC)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -type f -name "*.sh" ! -path "./build/*" ! -path "./dist/*" ! -path "./release/*" -exec shellcheck -x {} + && \
		echo "$(GREEN)✓ Shellcheck passed$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Shellcheck not found, skipping$(NC)"; \
	fi

lint: check
	@echo "$(GREEN)→ Running additional linting...$(NC)"
	@echo "$(CYAN)  Checking for common issues...$(NC)"
	@! grep -r "rm -rf /" . --include="*.sh" || { echo "$(RED)✗ Dangerous rm -rf / found$(NC)"; exit 1; }
	@! grep -rn "eval " . --include="*.sh" --exclude-dir=build --exclude-dir=dist || echo "$(YELLOW)⚠ eval usage detected$(NC)"
	@echo "$(GREEN)✓ Lint checks complete$(NC)"

format:
	@echo "$(GREEN)→ Formatting shell scripts...$(NC)"
	@if command -v shfmt >/dev/null 2>&1; then \
		find . -type f -name "*.sh" ! -path "./build/*" ! -path "./dist/*" -exec shfmt -w -i 4 -ci {} + && \
		echo "$(GREEN)✓ Formatting complete$(NC)"; \
	else \
		echo "$(YELLOW)⚠ shfmt not found, skipping$(NC)"; \
	fi

# Testing
test: check
	@echo "$(GREEN)→ Running tests...$(NC)"
	@echo "$(CYAN)  Testing module structure...$(NC)"
	@test -f module.prop || { echo "$(RED)✗ module.prop not found$(NC)"; exit 1; }
	@test -f install.sh || { echo "$(RED)✗ install.sh not found$(NC)"; exit 1; }
	@test -f META-INF/com/google/android/update-binary || { echo "$(RED)✗ update-binary not found$(NC)"; exit 1; }
	@echo "$(CYAN)  Testing shell syntax...$(NC)"
	@find . -name "*.sh" ! -path "./build/*" -exec bash -n {} \;
	@echo "$(CYAN)  Checking module.prop format...$(NC)"
	@grep -q "^id=" module.prop || { echo "$(RED)✗ Invalid module.prop$(NC)"; exit 1; }
	@grep -q "^version=" module.prop || { echo "$(RED)✗ Invalid module.prop$(NC)"; exit 1; }
	@echo "$(GREEN)✓ All tests passed$(NC)"

# ADB deployment
install-adb: build
	@echo "$(GREEN)→ Installing to device via ADB...$(NC)"
	@if ! command -v adb >/dev/null 2>&1; then \
		echo "$(RED)✗ ADB not found. Please install Android SDK Platform Tools$(NC)"; \
		exit 1; \
	fi
	@if ! adb devices | grep -q "device$$"; then \
		echo "$(RED)✗ No device connected$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)  Pushing module to device...$(NC)"
	@adb push $(MODULE_ID)-$(VERSION).zip /sdcard/Download/
	@echo "$(GREEN)✓ Module pushed to /sdcard/Download/$(NC)"
	@echo "$(YELLOW)  Install via Magisk Manager or flash in recovery$(NC)"

push-device: build
	@echo "$(GREEN)→ Pushing to device storage...$(NC)"
	@adb push $(MODULE_ID)-$(VERSION).zip /sdcard/Download/$(MODULE_ID)-$(VERSION).zip
	@echo "$(GREEN)✓ Pushed to /sdcard/Download/$(NC)"

uninstall-adb:
	@echo "$(GREEN)→ Uninstalling from device...$(NC)"
	@adb shell su -c "magisk --remove-modules" || \
	adb shell su -c "rm -rf /data/adb/modules/$(MODULE_ID)"
	@echo "$(GREEN)✓ Module uninstalled$(NC)"

# Clean build artifacts
clean:
	@echo "$(GREEN)→ Cleaning build artifacts...$(NC)"
	@rm -rf $(BUILD_DIR)
	@rm -rf $(DIST_DIR)
	@rm -f $(MODULE_ID)-*.zip
	@rm -f *.zip.sha256
	@find . -type f -name "*.bak" -delete
	@find . -type f -name "*~" -delete
	@echo "$(GREEN)✓ Clean complete$(NC)"

# Info
info:
	@echo "$(BLUE)Module Information:$(NC)"
	@echo "  ID:          $(MODULE_ID)"
	@echo "  Name:        $(MODULE_NAME)"
	@echo "  Version:     $(VERSION)"
	@echo "  Version Code:$(VERSION_CODE)"
	@echo "  Author:      $(shell grep -oP '(?<=author=).*' module.prop)"
	@echo ""
	@echo "$(BLUE)Build Status:$(NC)"
	@if [ -f "$(MODULE_ID)-$(VERSION).zip" ]; then \
		echo "  Latest build: $(GREEN)✓ Present$(NC)"; \
		ls -lh $(MODULE_ID)-$(VERSION).zip; \
	else \
		echo "  Latest build: $(YELLOW)✗ Not found$(NC)"; \
	fi

# Watch for changes (requires inotify-tools)
watch:
	@echo "$(GREEN)→ Watching for changes...$(NC)"
	@while true; do \
		inotifywait -r -e modify,create,delete --exclude '(build|dist|\.git)' . && \
		$(MAKE) build; \
	done

# Create changelog
changelog:
	@echo "$(GREEN)→ Generating changelog...$(NC)"
	@if [ -d .git ]; then \
		git log --oneline --decorate --graph > CHANGELOG.md; \
		echo "$(GREEN)✓ Changelog generated$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Not a git repository$(NC)"; \
	fi

# Device info
device-info:
	@echo "$(GREEN)→ Getting device info...$(NC)"
	@adb shell getprop ro.product.model
	@adb shell getprop ro.build.version.release
	@adb shell getprop ro.product.cpu.abi
	@echo ""
	@echo "$(CYAN)Magisk info:$(NC)"
	@adb shell su -c "magisk -v" || echo "$(YELLOW)Magisk not found$(NC)"
	@echo ""
	@echo "$(CYAN)Current zRAM status:$(NC)"
	@adb shell cat /proc/swaps || echo "$(YELLOW)No swap active$(NC)"