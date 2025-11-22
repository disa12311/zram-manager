# Makefile for zram-manager
# Optimized for build automation and CI/CD

# Variables
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib
SYSCONFDIR = /etc
SYSTEMDDIR = /lib/systemd/system

INSTALL = install
INSTALL_PROGRAM = $(INSTALL) -m 0755
INSTALL_DATA = $(INSTALL) -m 0644

# Project files
SCRIPT_NAME = zram-manager
SERVICE_NAME = zram-manager.service
CONFIG_NAME = zram-manager.conf

# Build tools
SHELLCHECK ?= shellcheck
SHFMT ?= shfmt

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[0;33m
NC = \033[0m # No Color

.PHONY: all install uninstall check format test clean help

# Default target
all: check

# Help target
help:
	@echo "$(GREEN)zram-manager Makefile$(NC)"
	@echo ""
	@echo "Available targets:"
	@echo "  $(YELLOW)make install$(NC)     - Install zram-manager to system"
	@echo "  $(YELLOW)make uninstall$(NC)   - Remove zram-manager from system"
	@echo "  $(YELLOW)make check$(NC)       - Run shellcheck on scripts"
	@echo "  $(YELLOW)make format$(NC)      - Format shell scripts with shfmt"
	@echo "  $(YELLOW)make test$(NC)        - Run tests"
	@echo "  $(YELLOW)make clean$(NC)       - Clean build artifacts"
	@echo "  $(YELLOW)make package$(NC)     - Create distribution package"
	@echo ""
	@echo "Installation options:"
	@echo "  PREFIX=$(PREFIX)    - Installation prefix (default: /usr/local)"

# Install to system
install:
	@echo "$(GREEN)Installing zram-manager...$(NC)"
	$(INSTALL) -d $(DESTDIR)$(BINDIR)
	$(INSTALL) -d $(DESTDIR)$(SYSCONFDIR)
	$(INSTALL_PROGRAM) $(SCRIPT_NAME) $(DESTDIR)$(BINDIR)/$(SCRIPT_NAME)
	@if [ -f $(CONFIG_NAME) ]; then \
		$(INSTALL_DATA) $(CONFIG_NAME) $(DESTDIR)$(SYSCONFDIR)/$(CONFIG_NAME); \
	fi
	@if [ -f $(SERVICE_NAME) ]; then \
		$(INSTALL) -d $(DESTDIR)$(SYSTEMDDIR); \
		$(INSTALL_DATA) $(SERVICE_NAME) $(DESTDIR)$(SYSTEMDDIR)/$(SERVICE_NAME); \
		echo "$(YELLOW)Run 'systemctl daemon-reload' to reload systemd$(NC)"; \
	fi
	@echo "$(GREEN)Installation complete!$(NC)"

# Uninstall from system
uninstall:
	@echo "$(RED)Uninstalling zram-manager...$(NC)"
	rm -f $(DESTDIR)$(BINDIR)/$(SCRIPT_NAME)
	rm -f $(DESTDIR)$(SYSCONFDIR)/$(CONFIG_NAME)
	@if [ -f $(DESTDIR)$(SYSTEMDDIR)/$(SERVICE_NAME) ]; then \
		systemctl stop $(SERVICE_NAME) 2>/dev/null || true; \
		systemctl disable $(SERVICE_NAME) 2>/dev/null || true; \
		rm -f $(DESTDIR)$(SYSTEMDDIR)/$(SERVICE_NAME); \
		systemctl daemon-reload; \
	fi
	@echo "$(GREEN)Uninstallation complete!$(NC)"

# Check shell scripts with shellcheck
check:
	@echo "$(GREEN)Running shellcheck...$(NC)"
	@if command -v $(SHELLCHECK) >/dev/null 2>&1; then \
		find . -type f -name "*.sh" -o -name $(SCRIPT_NAME) | xargs $(SHELLCHECK) -x || exit 1; \
		echo "$(GREEN)✓ Shellcheck passed$(NC)"; \
	else \
		echo "$(YELLOW)Warning: shellcheck not found, skipping checks$(NC)"; \
	fi

# Format shell scripts
format:
	@echo "$(GREEN)Formatting shell scripts...$(NC)"
	@if command -v $(SHFMT) >/dev/null 2>&1; then \
		find . -type f -name "*.sh" -o -name $(SCRIPT_NAME) | xargs $(SHFMT) -w -i 4 -ci; \
		echo "$(GREEN)✓ Formatting complete$(NC)"; \
	else \
		echo "$(YELLOW)Warning: shfmt not found, skipping formatting$(NC)"; \
	fi

# Run tests
test: check
	@echo "$(GREEN)Running tests...$(NC)"
	@if [ -d tests ]; then \
		./tests/run_tests.sh || exit 1; \
		echo "$(GREEN)✓ All tests passed$(NC)"; \
	else \
		echo "$(YELLOW)No tests directory found$(NC)"; \
	fi

# Create distribution package
package: check
	@echo "$(GREEN)Creating distribution package...$(NC)"
	@VERSION=$$(grep -oP '(?<=VERSION=")[^"]*' $(SCRIPT_NAME) || echo "1.0.0"); \
	PKG_NAME="zram-manager-$$VERSION"; \
	mkdir -p dist/$$PKG_NAME; \
	cp -r $(SCRIPT_NAME) $(SERVICE_NAME) $(CONFIG_NAME) README* LICENSE* dist/$$PKG_NAME/ 2>/dev/null || true; \
	cd dist && tar czf $$PKG_NAME.tar.gz $$PKG_NAME; \
	rm -rf $$PKG_NAME; \
	echo "$(GREEN)✓ Package created: dist/$$PKG_NAME.tar.gz$(NC)"

# Clean build artifacts
clean:
	@echo "$(GREEN)Cleaning...$(NC)"
	rm -rf dist/
	find . -type f -name "*.bak" -delete
	find . -type f -name "*~" -delete
	@echo "$(GREEN)✓ Clean complete$(NC)"

# Development targets
dev-setup:
	@echo "$(GREEN)Setting up development environment...$(NC)"
	@command -v shellcheck >/dev/null 2>&1 || echo "$(YELLOW)Install shellcheck: apt install shellcheck$(NC)"
	@command -v shfmt >/dev/null 2>&1 || echo "$(YELLOW)Install shfmt: go install mvdan.cc/sh/v3/cmd/shfmt@latest$(NC)"

# Quick install for development (no sudo needed)
dev-install:
	@echo "$(GREEN)Installing to ~/.local/bin$(NC)"
	mkdir -p ~/.local/bin
	cp $(SCRIPT_NAME) ~/.local/bin/
	chmod +x ~/.local/bin/$(SCRIPT_NAME)
	@echo "$(GREEN)✓ Installed to ~/.local/bin (add to PATH if needed)$(NC)"