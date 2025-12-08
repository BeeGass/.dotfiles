# Testing Guidelines

## Testing Philosophy

- **Test behavior, not implementation**: Focus on what code does, not how
- **Test pyramid**: Many unit tests, fewer integration tests, few e2e tests
- **Fast feedback**: Tests should run quickly during development
- **Deterministic tests**: No flaky tests, no random data without seeds
- **Clear test names**: Test names should describe the scenario and expected outcome

## Test Coverage

- **Aim for high coverage** of critical paths and business logic
- **100% coverage not required**: Focus on meaningful tests over metrics
- **Test edge cases**: Null/undefined, empty arrays, boundary conditions
- **Test error paths**: Verify error handling works correctly

## Testing Frameworks

- **JavaScript/TypeScript**: Jest or Vitest
- **Python**: pytest with fixtures and parametrize
- **Rust**: Built-in `cargo test` with `#[test]` and doc tests
- **ML/JAX**: Unit tests for transformations, integration tests for training loops

## Regression Testing

- **Always add tests** for bugs before fixing them
- **Snapshot tests** for complex outputs (with caution)
- **Golden file tests** for deterministic outputs
- **Version compatibility tests** when applicable

## Integration Testing

- **Test real interactions**: Use real databases/services in test mode when possible
- **Test containers**: Use Docker/testcontainers for complex dependencies
- **Mock sparingly**: Only mock external services you don't control
- **Test failure modes**: Verify behavior when dependencies fail
- **End-to-end critical paths**: Test complete user workflows for critical features
