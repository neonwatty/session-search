.PHONY: build test app-smoke ui-smoke marketing-assets demo-gif install install-login clean generate

APP_NAME := SessionSearch
PROJ := $(APP_NAME).xcodeproj
BUILD_DIR := build
INSTALL_DIR := $(HOME)/Applications
XCODEBUILD_ARGS ?=

generate:
	xcodegen generate

build: generate
	xcodebuild build \
	  -project $(PROJ) -scheme $(APP_NAME) \
	  -configuration Release -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR) \
	  $(XCODEBUILD_ARGS)

test: generate
	xcodebuild test \
	  -project $(PROJ) -scheme $(APP_NAME) \
	  -destination 'platform=macOS' \
	  -derivedDataPath $(BUILD_DIR)

ui-smoke: XCODEBUILD_ARGS += ENABLE_HARDENED_RUNTIME=NO
ui-smoke: build
	./scripts/ui-smoke.sh "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app"

marketing-assets: XCODEBUILD_ARGS += ENABLE_HARDENED_RUNTIME=NO
marketing-assets: build
	./scripts/capture-marketing-assets.sh "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app"

demo-gif: XCODEBUILD_ARGS += ENABLE_HARDENED_RUNTIME=NO
demo-gif: build
	./scripts/capture-demo-gif.sh "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app"

app-smoke: XCODEBUILD_ARGS += ENABLE_HARDENED_RUNTIME=NO
app-smoke: build
	./scripts/app-smoke.sh "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app"

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
