.PHONY: build release run install clean test dmg reinstall uninstall

# Development
build:
	swift build

run: build
	.build/debug/MonkMode

# Production
release:
	swift build -c release

install: release
	sudo cp .build/release/MonkMode /usr/local/bin/monkmode
	sudo cp .build/release/MonkModeEnforcer /usr/local/bin/monkmode-enforcer
	sudo chmod +x /usr/local/bin/monkmode
	sudo chmod +x /usr/local/bin/monkmode-enforcer

dmg:
	./scripts/build_dmg.sh

# Rebuild the DMG, replace the /Applications copy, strip quarantine, and
# launch the fresh app. Handy for dogfooding after every change.
reinstall: dmg
	rm -rf /Applications/MonkMode.app
	cp -R dist/MonkMode.app /Applications/
	xattr -cr /Applications/MonkMode.app
	open /Applications/MonkMode.app

# Privileged uninstall via the bundled script.
uninstall:
	sudo ./scripts/uninstall.sh

# Testing
test:
	swift test

# Cleanup
clean:
	swift package clean
	rm -rf .build dist
