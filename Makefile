.PHONY: build release run install clean test dmg

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

# Testing
test:
	swift test

# Cleanup
clean:
	swift package clean
	rm -rf .build dist
