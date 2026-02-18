.PHONY: build release run install clean test

# Development
build:
	swift build

run: build
	.build/debug/BlockSitesApp

# Production
release:
	swift build -c release

install: release
	sudo cp .build/release/BlockSitesApp /usr/local/bin/blocksites
	sudo cp .build/release/BlockSitesEnforcer /usr/local/bin/blocksites-enforcer
	sudo chmod +x /usr/local/bin/blocksites
	sudo chmod +x /usr/local/bin/blocksites-enforcer

# Testing
test:
	swift test

# Cleanup
clean:
	swift package clean
