APP_NAME = leCG
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = /Applications

.PHONY: all build run install package clean

all: build

build:
	./build_app.sh

run: build
	open $(APP_BUNDLE)

install: build
	@echo "Installing $(APP_BUNDLE) to $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_BUNDLE)"
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "Installed! You can find leCG in Applications or Spotlight."

package:
	./package_release.sh

clean:
	rm -rf $(APP_BUNDLE) $(APP_NAME) dist .build
