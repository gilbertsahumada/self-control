.PHONY: build release run status install clean test test-cleanup

# Development
build:
	swift build

run: build
	sudo .build/debug/BlockSites

status: build
	.build/debug/BlockSites --status

# Production
release:
	swift build -c release

install: release
	sudo cp .build/release/BlockSites /usr/local/bin/blocksites
	sudo cp .build/release/BlockSitesEnforcer /usr/local/bin/blocksites-enforcer
	sudo chmod +x /usr/local/bin/blocksites
	sudo chmod +x /usr/local/bin/blocksites-enforcer

# Testing
test: build
	sudo ./test_blocking.sh

test-cleanup:
	sudo ./test_cleanup.sh

# Cleanup
clean:
	swift package clean
