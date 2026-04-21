.PHONY: build release run install clean test dmg

# Development
build:
	swift build

run: build
	.build/debug/SelfControl

# Production
release:
	swift build -c release

install: release
	sudo cp .build/release/SelfControl /usr/local/bin/selfcontrol
	sudo cp .build/release/SelfControlEnforcer /usr/local/bin/selfcontrol-enforcer
	sudo chmod +x /usr/local/bin/selfcontrol
	sudo chmod +x /usr/local/bin/selfcontrol-enforcer

dmg:
	./scripts/build_dmg.sh

# Testing
test:
	swift test

# Cleanup
clean:
	swift package clean
	rm -rf .build dist
