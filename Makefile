SHELL := /bin/zsh

PROJECT_ROOT := $(CURDIR)
SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
CLANG := $(shell xcrun --sdk iphoneos --find clang)
MIN_IOS ?= 15.0
EXTRA_CFLAGS ?=

DYLIB := $(PROJECT_ROOT)/build/IsaacDebugConsole.dylib
DEB_STAGE := $(PROJECT_ROOT)/package/stage
DEB := $(PROJECT_ROOT)/packages/IsaacDebugConsole-rootless.deb
LC_FRAMEWORK := $(PROJECT_ROOT)/build/IsaacDebugConsole.framework
LC_ZIP := $(PROJECT_ROOT)/packages/IsaacDebugConsole-LiveContainer.framework.zip
EMBEDDED_STAGE := $(PROJECT_ROOT)/build/IsaacDebugConsole-Embedded
EMBEDDED_ZIP := $(PROJECT_ROOT)/dist/IsaacDebugConsole-Embedded.zip

SOURCES := \
	$(PROJECT_ROOT)/src/IDCBootstrap.m \
	$(PROJECT_ROOT)/src/IDCLogger.m \
	$(PROJECT_ROOT)/src/IDCItemCatalog.m \
	$(PROJECT_ROOT)/src/IDCCommandEngine.m \
	$(PROJECT_ROOT)/src/IDCConsoleController.m \
	$(PROJECT_ROOT)/src/IDCNativeBridge.mm

.PHONY: all dylib package livecontainer embedded audit test release clean

all: dylib package

dylib:
	mkdir -p "$(PROJECT_ROOT)/build"
	"$(CLANG)" -isysroot "$(SDK)" -arch arm64 -miphoneos-version-min="$(MIN_IOS)" \
		-fobjc-arc -fblocks -fmodules -O2 $(EXTRA_CFLAGS) -dynamiclib \
		-I"$(PROJECT_ROOT)/include" -Wl,-install_name,@rpath/IsaacDebugConsole.dylib \
		-Wl,-dead_strip -Wl,-fatal_warnings $(SOURCES) \
		-framework Foundation -framework UIKit -framework QuartzCore -lc++ -o "$(DYLIB)"
	xcrun strip -x "$(DYLIB)"
	@if command -v codesign >/dev/null 2>&1; then \
		codesign --force --sign - --timestamp=none \
			--identifier com.emp0ry.isaacdebugconsole.dylib "$(DYLIB)"; \
	elif command -v ldid >/dev/null 2>&1; then ldid -S "$(DYLIB)"; fi

package: dylib
	rm -rf "$(DEB_STAGE)"
	mkdir -p "$(DEB_STAGE)/DEBIAN" \
		"$(DEB_STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries"
	cp "$(PROJECT_ROOT)/package/control" "$(DEB_STAGE)/DEBIAN/control"
	cp "$(PROJECT_ROOT)/package/IsaacDebugConsole.plist" \
		"$(DEB_STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries/IsaacDebugConsole.plist"
	cp "$(DYLIB)" \
		"$(DEB_STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries/IsaacDebugConsole.dylib"
	mkdir -p "$(PROJECT_ROOT)/packages"
	dpkg-deb --root-owner-group --build "$(DEB_STAGE)" "$(DEB)"

livecontainer: dylib
	rm -rf "$(LC_FRAMEWORK)"
	mkdir -p "$(LC_FRAMEWORK)"
	cp "$(DYLIB)" "$(LC_FRAMEWORK)/IsaacDebugConsole"
	cp "$(PROJECT_ROOT)/livecontainer/Info.plist" "$(LC_FRAMEWORK)/Info.plist"
	chmod 755 "$(LC_FRAMEWORK)/IsaacDebugConsole"
	mkdir -p "$(PROJECT_ROOT)/packages"
	rm -f "$(LC_ZIP)"
	/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$(LC_FRAMEWORK)" "$(LC_ZIP)"

embedded: dylib
	rm -rf "$(EMBEDDED_STAGE)"
	mkdir -p "$(EMBEDDED_STAGE)" "$(PROJECT_ROOT)/dist"
	cp "$(DYLIB)" "$(EMBEDDED_STAGE)/IsaacDebugConsole.dylib"
	cp "$(PROJECT_ROOT)/README.md" "$(EMBEDDED_STAGE)/README.md"
	rm -f "$(EMBEDDED_ZIP)"
	/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$(EMBEDDED_STAGE)" "$(EMBEDDED_ZIP)"

audit: dylib
	file "$(DYLIB)"
	otool -L "$(DYLIB)"
	@if nm -u "$(DYLIB)" | rg -i 'substrate|ellekit|libhooker|/var/jb'; then \
		echo "ERROR: jailbreak-only dependency detected"; exit 1; \
	else echo "Portable dependency audit passed"; fi

test:
	python3 "$(PROJECT_ROOT)/tests/test_source_contract.py"
	plutil -lint "$(PROJECT_ROOT)/livecontainer/Info.plist"
	plutil -lint "$(PROJECT_ROOT)/package/IsaacDebugConsole.plist"

release:
	$(MAKE) test
	$(MAKE) package EXTRA_CFLAGS='-Wall -Wextra -Werror'
	$(MAKE) livecontainer EXTRA_CFLAGS='-Wall -Wextra -Werror'
	$(MAKE) embedded EXTRA_CFLAGS='-Wall -Wextra -Werror'
	$(MAKE) audit EXTRA_CFLAGS='-Wall -Wextra -Werror'
	mkdir -p "$(PROJECT_ROOT)/dist"
	cp "$(DYLIB)" "$(PROJECT_ROOT)/dist/IsaacDebugConsole.dylib"
	cp "$(DEB)" "$(PROJECT_ROOT)/dist/IsaacDebugConsole-rootless.deb"
	cp "$(LC_ZIP)" "$(PROJECT_ROOT)/dist/IsaacDebugConsole-LiveContainer.framework.zip"
	cd "$(PROJECT_ROOT)/dist" && shasum -a 256 \
		IsaacDebugConsole.dylib \
		IsaacDebugConsole-rootless.deb \
		IsaacDebugConsole-LiveContainer.framework.zip \
		IsaacDebugConsole-Embedded.zip > SHA256SUMS

clean:
	rm -rf "$(PROJECT_ROOT)/build" "$(PROJECT_ROOT)/package/stage" "$(PROJECT_ROOT)/dist"
	find "$(PROJECT_ROOT)/packages" -maxdepth 1 -type f -delete 2>/dev/null || true
