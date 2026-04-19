# Contributing to Front Porch AI

Thank you for your interest in contributing to Front Porch AI! This document provides guidelines and processes for contributing to the project. We welcome contributions from developers of all skill levels.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Required Checks](#required-checks)
- [Testing](#testing)
- [Building](#building)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

This project follows a code of conduct to ensure a welcoming environment for all contributors. Please be respectful and constructive in all interactions.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
3. **Set up the development environment** (see below)
4. **Create a feature branch** for your changes
5. **Make your changes** following the guidelines in [AGENTS.md](AGENTS.md)
6. **Run tests and linting** to ensure quality
7. **Submit a pull request** with a clear description

## Development Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.10.8 or later)
- [Rust toolchain](https://rustup.rs/) (for embedding server)
- [Git](https://git-scm.com/)
- Python 3.8+ (for TTS/STT scripts)
- One of: Windows 10+, macOS 10.14+, or Linux (Ubuntu 18.04+, Fedora 30+, or Arch Linux)

### Setup Steps

```bash
# Clone the repository
git clone https://github.com/your-username/front-porch-ai.git
cd front-porch-ai

# Install Flutter dependencies
flutter pub get

# Build the embedding server (Rust)
cargo build --release --manifest-path tools/embed_server/Cargo.toml

# Optional: Install Python dependencies for sidecars
pip install -r requirements.txt  # If requirements.txt exists
```

## Pull Request Process

1. **Ensure your branch is up-to-date** with the main branch
2. **Run all required checks** (see below)
3. **Write clear commit messages** following conventional commits
4. **Create a descriptive PR title and description**
5. **Reference any related issues**
6. **Request review** from maintainers

### PR Template

Please use the following template for pull requests:

```markdown
## Description
Brief description of the changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Refactoring

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing completed

## Screenshots (if applicable)
Add screenshots for UI changes

## Checklist
- [ ] Code follows style guidelines
- [ ] Linting passes
- [ ] Tests pass on all platforms
- [ ] Documentation updated
- [ ] No breaking changes
```

## Required Checks

All contributions must pass these checks before merging:

### Code Quality
- **Linting**: `flutter analyze`
- **Formatting**: `flutter format --set-exit-if-changed .`
- **Type checking**: Ensure no type errors

### Testing
- **Unit tests**: `flutter test`
- **Integration tests**: Run manual tests for core features

### Security
- No secrets or API keys in code
- Secure handling of user data
- No introduction of vulnerabilities

## Testing

### Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/path/to/test_file.dart
```

### Test Coverage Requirements

- Maintain or improve existing test coverage
- Add tests for new features
- Ensure tests pass on all target platforms

### Manual Testing

For features requiring manual testing:

1. Build the app for your platform
2. Test core functionality: chat, character loading, TTS, etc.
3. Verify on different screen sizes if UI changes
4. Test error handling and edge cases

## Building

### All Platforms

```bash
# Debug build
flutter run

# Release build for current platform
flutter build <platform>  # linux, windows, or macos
```

### Platform-Specific Builds

#### Linux
```bash
flutter build linux
# Copy embedding server
cp tools/embed_server/target/release/embed_server build/linux/x64/release/bundle/embed_server/
```

#### macOS
```bash
./scripts/build-macos.sh
```

#### Windows
```bash
flutter build windows
# Copy embedding server
copy tools\embed_server\target\release\embed_server.exe build\windows\x64\runner\Release\embed_server.exe
```

### Release Checklist

- [ ] Version bumped in `pubspec.yaml`
- [ ] Changelog updated
- [ ] All tests pass
- [ ] Builds successfully on all platforms
- [ ] Manual testing completed
- [ ] Documentation updated

## Reporting Issues

When reporting bugs or requesting features:

1. **Check existing issues** first
2. **Use issue templates** when available
3. **Provide detailed information**:
   - Steps to reproduce
   - Expected vs actual behavior
   - Platform and version information
   - Screenshots/logs if applicable
4. **Be specific** and include minimal reproduction cases

## Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- [Project Architecture](AGENTS.md#project-architecture-overview)
- [Discord Community](https://discord.gg/e4tET6rpdv)

Thank you for contributing to Front Porch AI! 🎭</content>
<parameter name="filePath">CONTRIBUTING.md