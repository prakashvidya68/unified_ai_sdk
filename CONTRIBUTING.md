# Contributing to Unified AI SDK

Thank you for your interest in contributing to the Unified AI SDK! We welcome contributions from the community to help make this the best unified interface for AI providers in Dart and Flutter.

## Getting Started

### Prerequisites

- **Dart SDK**: Version 3.0.0 or higher.
- **Git**: For version control.

### Installation

1.  **Clone the repository**:

    ```bash
    git clone https://github.com/prakashvidya68/unified_ai_sdk.git
    cd unified_ai_sdk
    ```

2.  **Install dependencies**:
    ```bash
    dart pub get
    ```

## Development Workflow

### 1. Code Style & Linting

We enforce strict type checking and code style rules to ensure high code quality.

- **Formatting**: We use the standard Dart formatter.
  ```bash
  dart format .
  ```
- **Analysis**: Run the analyzer to check for errors and warnings. Note that we treat infos as fatal in CI.
  ```bash
  dart analyze --fatal-infos
  ```

### 2. Running Tests

This project uses the `test` package. Please ensure all tests pass before submitting your changes.

- **Run all tests**:
  ```bash
  dart test
  ```
- **Run specific test file**:
  ```bash
  dart test test/path/to/file_test.dart
  ```

### 3. Folder Structure

- `lib/src/providers/`: Implementations for specific AI providers (OpenAI, Anthropic, etc.).
- `lib/src/models/`: Data models for requests and responses.
- `lib/src/core/`: Core logic like authentication and configuration.
- `example/`: Usage examples. Please add an example if you implement a major new feature.
- `test/`: Unit and integration tests.

## Submitting a Pull Request (PR)

1.  **Fork the repository** and create your branch from `main`.
2.  **Add tests** for any new functionality or bug fixes.
3.  **Update documentation** (comments and README) if necessary.
4.  **Verify your code**:
    - Run `dart format .`
    - Run `dart analyze --fatal-infos`
    - Run `dart test`
5.  **Submit the PR** with a clear description of the changes.

### Checklist

- [ ] Code compiles correctly.
- [ ] All tests pass.
- [ ] Code is formatted (`dart format .`).
- [ ] No analyzer warnings (`dart analyze`).
- [ ] Dependencies are up to date.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
