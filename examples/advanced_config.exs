#!/usr/bin/env elixir

# Advanced Configuration Example
# Run with: mix run examples/advanced_config.exs

Mix.install([{:elixact, path: "."}])

IO.puts("""
⚙️ Elixact Advanced Configuration Example
=========================================

This example demonstrates runtime configuration modification, presets,
and the builder pattern for flexible validation behavior.
""")

# Example 1: Basic Configuration Creation
IO.puts("\n📝 Example 1: Basic Configuration Creation")

# Create configurations with different options
basic_config = Elixact.Config.create(%{
  strict: true,
  extra: :forbid,
  coercion: :safe
})

IO.puts("✅ Basic configuration created:")
IO.inspect(Elixact.Config.summary(basic_config), pretty: true)

# Create configuration from keyword list
keyword_config = Elixact.Config.create([
  strict: false,
  extra: :allow,
  coercion: :aggressive,
  error_format: :simple
])

IO.puts("✅ Keyword configuration created:")
IO.inspect(Elixact.Config.summary(keyword_config), pretty: true)

# Example 2: Configuration Presets
IO.puts("\n🎛️ Example 2: Configuration Presets")

# Test all available presets
presets = [:strict, :lenient, :api, :json_schema, :development, :production]

for preset <- presets do
  config = Elixact.Config.preset(preset)
  summary = Elixact.Config.summary(config)
  IO.puts("✅ #{preset} preset: #{summary.validation_mode} validation, #{summary.coercion} coercion")
end

# Example 3: Configuration Merging
IO.puts("\n🔀 Example 3: Configuration Merging")

# Start with a base configuration
base_config = Elixact.Config.create(%{
  strict: false,
  extra: :allow,
  coercion: :safe
})

# Merge with overrides
strict_override = Elixact.Config.merge(base_config, %{
  strict: true,
  extra: :forbid,
  error_format: :detailed
})

IO.puts("Base config: #{Elixact.Config.summary(base_config).validation_mode}")
IO.puts("Merged config: #{Elixact.Config.summary(strict_override).validation_mode}")

# Test frozen configuration behavior
frozen_config = Elixact.Config.create(%{frozen: true, strict: true})
IO.puts("✅ Frozen config created")

# Try to merge with frozen config (empty merge should work)
try do
  empty_merge = Elixact.Config.merge(frozen_config, %{})
  IO.puts("✅ Empty merge with frozen config succeeded")
rescue
  RuntimeError -> 
    IO.puts("❌ Empty merge with frozen config failed (unexpected)")
end

# Try to merge with non-empty override (should fail)
try do
  Elixact.Config.merge(frozen_config, %{strict: false})
  IO.puts("❌ Non-empty merge with frozen config succeeded (unexpected)")
rescue
  RuntimeError -> 
    IO.puts("✅ Non-empty merge with frozen config failed (expected)")
end

# Example 4: Builder Pattern
IO.puts("\n🏗️ Example 4: Builder Pattern")

# Build configuration fluently
api_config = Elixact.Config.builder()
|> Elixact.Config.Builder.strict(true)
|> Elixact.Config.Builder.forbid_extra()
|> Elixact.Config.Builder.safe_coercion()
|> Elixact.Config.Builder.detailed_errors()
|> Elixact.Config.Builder.frozen(true)
|> Elixact.Config.Builder.build()

IO.puts("✅ API config built:")
IO.inspect(Elixact.Config.summary(api_config), pretty: true)

# Build configuration with convenience methods
dev_config = Elixact.Config.builder()
|> Elixact.Config.Builder.allow_extra()
|> Elixact.Config.Builder.aggressive_coercion()
|> Elixact.Config.Builder.case_insensitive()
|> Elixact.Config.Builder.simple_errors()
|> Elixact.Config.Builder.build()

IO.puts("✅ Development config built:")
IO.inspect(Elixact.Config.summary(dev_config), pretty: true)

# Example 5: Conditional Configuration
IO.puts("\n🔀 Example 5: Conditional Configuration")

# Build configuration based on environment
env = :production  # Simulate production environment

prod_config = Elixact.Config.builder()
|> Elixact.Config.Builder.when_true(env == :production, fn builder ->
  builder
  |> Elixact.Config.Builder.strict(true)
  |> Elixact.Config.Builder.forbid_extra()
  |> Elixact.Config.Builder.frozen(true)
end)
|> Elixact.Config.Builder.when_true(env == :development, fn builder ->
  builder
  |> Elixact.Config.Builder.allow_extra()
  |> Elixact.Config.Builder.aggressive_coercion()
end)
|> Elixact.Config.Builder.build()

IO.puts("✅ Environment-specific config (#{env}):")
IO.inspect(Elixact.Config.summary(prod_config), pretty: true)

# Example 6: Preset Application with Builder
IO.puts("\n🎨 Example 6: Preset Application with Builder")

# Start with a preset and customize it
custom_api_config = Elixact.Config.builder()
|> Elixact.Config.Builder.apply_preset(:api)
|> Elixact.Config.Builder.case_insensitive()  # Override case sensitivity
|> Elixact.Config.Builder.max_union_length(10)  # Custom union length
|> Elixact.Config.Builder.build()

IO.puts("✅ Customized API config:")
IO.inspect(Elixact.Config.summary(custom_api_config), pretty: true)

# Example 7: Configuration for Different Use Cases
IO.puts("\n🎯 Example 7: Configuration for Different Use Cases")

# Configuration for API endpoints
api_endpoint_config = Elixact.Config.builder()
|> Elixact.Config.Builder.for_api()
|> Elixact.Config.Builder.build()

# Configuration for JSON schema generation
schema_gen_config = Elixact.Config.builder()
|> Elixact.Config.Builder.for_json_schema()
|> Elixact.Config.Builder.build()

# Configuration for development
development_config = Elixact.Config.builder()
|> Elixact.Config.Builder.for_development()
|> Elixact.Config.Builder.build()

# Configuration for production
production_config = Elixact.Config.builder()
|> Elixact.Config.Builder.for_production()
|> Elixact.Config.Builder.build()

use_cases = [
  {"API Endpoint", api_endpoint_config},
  {"JSON Schema", schema_gen_config},
  {"Development", development_config},
  {"Production", production_config}
]

for {name, config} <- use_cases do
  summary = Elixact.Config.summary(config)
  IO.puts("✅ #{name}: #{summary.validation_mode}, extra: #{summary.extra_fields}")
end

# Example 8: Configuration Validation and Error Handling
IO.puts("\n🚨 Example 8: Configuration Validation and Error Handling")

# Create a valid configuration
valid_config = Elixact.Config.create(%{strict: true, extra: :forbid})

case Elixact.Config.validate_config(valid_config) do
  :ok ->
    IO.puts("✅ Valid configuration passed validation")
  {:error, reasons} ->
    IO.puts("❌ Valid configuration failed: #{inspect(reasons)}")
end

# Test invalid configuration options
try do
  Elixact.Config.create(%{invalid_option: true})
  IO.puts("❌ Invalid option accepted (unexpected)")
rescue
  ArgumentError -> 
    IO.puts("✅ Invalid option rejected (expected)")
end

# Example 9: Configuration Conversion
IO.puts("\n🔄 Example 9: Configuration Conversion")

# Create a comprehensive configuration
comprehensive_config = Elixact.Config.create(%{
  strict: true,
  extra: :forbid,
  coercion: :safe,
  validate_assignment: true,
  case_sensitive: false,
  error_format: :detailed,
  use_enum_values: true,
  max_anyof_union_len: 3
})

# Convert to validation options
validation_opts = Elixact.Config.to_validation_opts(comprehensive_config)
IO.puts("✅ Validation options:")
IO.inspect(validation_opts, pretty: true)

# Convert to JSON schema options
json_schema_opts = Elixact.Config.to_json_schema_opts(comprehensive_config)
IO.puts("✅ JSON Schema options:")
IO.inspect(json_schema_opts, pretty: true)

# Example 10: Configuration Testing and Validation
IO.puts("\n🧪 Example 10: Configuration Testing with Real Data")

# Create test schema and data
test_schema = Elixact.Runtime.create_schema([
  {:name, :string, [required: true, min_length: 2]},
  {:email, :string, [required: true, format: ~r/@/]},
  {:age, :integer, [required: false, gt: 0]}
])

test_data = %{
  name: "John",
  email: "john@example.com",
  age: "30",  # String that can be coerced
  extra_field: "should be handled per config"
}

# Test different configurations
test_configs = [
  {"Strict + No Coercion", Elixact.Config.preset(:strict)},
  {"Lenient + Safe Coercion", Elixact.Config.preset(:lenient)},
  {"Development", Elixact.Config.preset(:development)},
  {"Production", Elixact.Config.preset(:production)}
]

for {name, config} <- test_configs do
  case Elixact.EnhancedValidator.validate(test_schema, test_data, config: config) do
    {:ok, validated} ->
      IO.puts("✅ #{name}: Validation succeeded")
      IO.puts("   Age coerced: #{inspect(validated.age)} (#{typeof(validated.age)})")
    {:error, errors} ->
      IO.puts("❌ #{name}: Validation failed")
      IO.puts("   Reason: #{hd(errors).message}")
  end
end

# Helper function to show type
defp typeof(value) when is_integer(value), do: "integer"
defp typeof(value) when is_binary(value), do: "string"
defp typeof(value) when is_float(value), do: "float"
defp typeof(value) when is_boolean(value), do: "boolean"
defp typeof(_), do: "other"

# Example 11: Builder Validation and Error Recovery
IO.puts("\n🔧 Example 11: Builder Validation and Error Recovery")

# Create a builder and validate before building
builder = Elixact.Config.builder()
|> Elixact.Config.Builder.strict(true)
|> Elixact.Config.Builder.forbid_extra()
|> Elixact.Config.Builder.safe_coercion()

case Elixact.Config.Builder.validate_and_build(builder) do
  {:ok, config} ->
    IO.puts("✅ Builder validation succeeded")
    IO.inspect(Elixact.Config.summary(config), pretty: true)
  {:error, reasons} ->
    IO.puts("❌ Builder validation failed: #{inspect(reasons)}")
end

# Example 12: Configuration Introspection
IO.puts("\n🔍 Example 12: Configuration Introspection")

# Create a complex configuration
complex_config = Elixact.Config.builder()
|> Elixact.Config.Builder.strict(true)
|> Elixact.Config.Builder.safe_coercion()
|> Elixact.Config.Builder.validate_assignment(true)
|> Elixact.Config.Builder.use_enum_values(true)
|> Elixact.Config.Builder.case_sensitive(false)
|> Elixact.Config.Builder.build()

# Inspect configuration properties
IO.puts("✅ Configuration introspection:")
IO.puts("   Allow extra fields: #{Elixact.Config.allow_extra_fields?(complex_config)}")
IO.puts("   Should coerce: #{Elixact.Config.should_coerce?(complex_config)}")
IO.puts("   Coercion level: #{Elixact.Config.coercion_level(complex_config)}")

summary = Elixact.Config.summary(complex_config)
IO.puts("   Enabled features: #{inspect(summary.features)}")

IO.puts("""

🎯 Summary
==========
This example demonstrated:
1. 📝 Basic configuration creation from maps and keywords
2. 🎛️ Predefined configuration presets for common scenarios
3. 🔀 Configuration merging with frozen config behavior
4. 🏗️ Fluent builder pattern for readable configuration
5. 🔀 Conditional configuration based on environment
6. 🎨 Preset application with builder customization
7. 🎯 Purpose-built configurations for different use cases
8. 🚨 Configuration validation and error handling
9. 🔄 Configuration conversion to validation options
10. 🧪 Real-world testing with different configurations
11. 🔧 Builder validation and error recovery
12. 🔍 Configuration introspection and property checking

Advanced Configuration enables DSPy-style ConfigDict patterns with
runtime modification, immutability controls, and flexible validation behavior.
""")

# Clean exit
:ok
