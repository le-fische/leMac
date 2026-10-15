APP_NAME = leCPUGPU
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = /Applications

.PHONY: all build run install clean

all: build

build:
	./build_app.sh

run: build
	open $(APP_BUNDLE)

install: build
	@echo "Installing $(APP_BUNDLE) to $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_BUNDLE)"
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "Installed! You can find leCPUGPU in Applications or Spotlight."

clean:
	rm -rf $(APP_BUNDLE) $(APP_NAME)
