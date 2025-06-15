Usage
To run the complete test suite:
bash# Run all tests
mix test

# Run specific test files
mix test test/elixact/runtime_test.exs
mix test test/elixact/type_adapter_test.exs
mix test test/elixact/integration_test.exs

# Run with coverage
mix test --cover

# Run performance tests
mix test --include slow

# Run integration tests
mix test --include integration

