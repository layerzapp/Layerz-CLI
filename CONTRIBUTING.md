# Contributing to Console

Thank you for your interest in contributing! Here's how to get started.

## Development Setup

1. **Requirements**: macOS 13+, Xcode 16+
2. Clone the repository and open `Console.xcodeproj`
3. Xcode will automatically download SPM dependencies (SwiftTerm)
4. Build and run (Cmd+R)

> The project uses Xcode's folder references. New files added to `Sources/` are automatically included in the build. Do not use XcodeGen or any other project generation tools.

## How to Contribute

### Reporting Bugs

- Open an issue with a clear description
- Include macOS version, Xcode version, and steps to reproduce
- Attach console logs or screenshots if applicable

### Suggesting Features

- Open an issue tagged as a feature request
- Describe the use case and expected behavior

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch from `develop` (`git checkout -b feature/my-feature develop`)
3. Make your changes
4. Test on macOS 13+ to ensure backward compatibility
5. Submit a PR against the `develop` branch

### Coding Guidelines

- **Swift**: Follow the conventions in `CLAUDE.md`
- **SwiftUI views**: Extract sub-views as `private var` computed properties
- **State sharing**: Use `@EnvironmentObject` for `AppState`, never pass it via `init`
- **Threading**: File I/O on `.global(qos: .userInitiated)`, UI updates on `.main.async`
- **Comments**: English only. Prefer `// TODO:` over `print()` for debugging

### Commit Messages

- Write in English
- Use concise, descriptive messages (e.g., `fix: resolve OSC 7 parsing for paths with spaces`)

## Code of Conduct

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before participating.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
