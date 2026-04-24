.PHONY: build test install install-login clean generate

APP_NAME := SessionSearch
PROJ := $(APP_NAME).xcodeproj
BUILD_DIR := build
INSTALL_DIR := $(HOME)/Applications

generate:
	xcodegen generate

build: generate
	xcodebuild build \
	  -project $(PROJ) -scheme $(APP_NAME) \
	  -configuration Release -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

test: generate
	xcodebuild test \
	  -project $(PROJ) -scheme $(APP_NAME) \
	  -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

install: build
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	cp -R $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app $(INSTALL_DIR)/
	@if [ -f "$(HOME)/Library/LaunchAgents/com.neonwatty.$(APP_NAME).plist" ]; then \
	  echo "LaunchAgent detected -- restarting managed instance"; \
	  launchctl kickstart -k "gui/$$(id -u)/com.neonwatty.$(APP_NAME)"; \
	else \
	  open $(INSTALL_DIR)/$(APP_NAME).app; \
	fi

install-login:
	./scripts/install-login-item.sh

clean:
	rm -rf $(PROJ) $(BUILD_DIR)
