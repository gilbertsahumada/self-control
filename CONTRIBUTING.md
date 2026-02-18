# Contributing to BlockSites

Thanks for your interest in contributing! This guide will help you get started.

## Getting Started

### Prerequisites

- macOS 13 (Ventura) or later
- Swift 5.9+
- Xcode 15+ or just the Swift toolchain

### Setup

```bash
git clone https://github.com/your-username/blocksites.git
cd blocksites
swift build
swift test
```

### Running the app

```bash
# Debug build + run
swift build && .build/debug/BlockSitesApp
```

No `sudo` needed to launch — the app requests admin privileges through the native macOS password dialog when you start a block.

## Project Structure

```
Sources/
  BlockSitesCore/       # Shared library (domain expansion, hosts generation, models)
  BlockSitesApp/        # SwiftUI macOS app
    Views/              # SwiftUI views
    ViewModels/         # ObservableObject view models
    Services/           # Privilege escalation, firewall management
    Models/             # Data models
  BlockSitesEnforcer/   # Background daemon (re-applies blocks every 60s)
Tests/
  BlockSitesCoreTests/  # Unit tests for the core library
```

## How to Contribute

### Reporting Bugs

- Use the **Bug Report** issue template
- Include your macOS version and Swift version (`swift --version`)
- Describe what you expected vs. what happened
- Steps to reproduce are very helpful

### Suggesting Features

- Use the **Feature Request** issue template
- Explain the problem you're trying to solve
- Describe your proposed solution

### Submitting Code

1. Fork the repository
2. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes
4. Make sure everything builds and tests pass:
   ```bash
   swift build
   swift test
   ```
5. Commit your changes with a clear message
6. Push to your fork and open a Pull Request

### Code Guidelines

- Follow existing code patterns and style
- Keep `BlockSitesCore` free of any UI or system dependencies — it's a pure logic library
- If you modify domain expansion or hosts generation logic, make sure it stays in sync between the app and the enforcer (both use `BlockSitesCore`)
- The `IPCache` struct in `BlockSitesApp/Services/FirewallManager.swift` must match the one in `BlockSitesEnforcer/FirewallManager.swift`
- Use `ObservableObject` / `@Published` (not `@Observable`) to maintain macOS 13 compatibility
- Add tests for new `BlockSitesCore` functionality

### What Makes a Good PR

- Focused on a single change
- Includes tests for new core logic
- Builds cleanly (`swift build`)
- All tests pass (`swift test`)
- Clear description of what and why

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
