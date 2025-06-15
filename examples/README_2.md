# Elixact Examples

This directory contains comprehensive examples showcasing all of Elixact's features, from basic validation to advanced DSPy integration patterns.

## Quick Start

Run any example with:
```bash
mix run examples/<example_name>.exs
```

## Example Overview

### Core Examples

#### 📝 [`basic_usage.exs`](basic_usage.exs)
- **What it covers**: Fundamental schema definition, validation, and error handling
- **Key concepts**: Basic types, constraints, field definitions, JSON schema generation
- **Best for**: Getting started with Elixact

#### 🏗️ [`advanced_features.exs`](advanced_features.exs)  
- **What it covers**: Complex schema patterns, nested validation, custom types
- **Key concepts**: Object types, unions, arrays, custom validation functions
- **Best for**: Understanding Elixact's advanced validation capabilities

#### 🎨 [`custom_validation.exs`](custom_validation.exs)
- **What it covers**: Custom validation functions, error messages, business logic
- **Key concepts**: Custom validators, error customization, transformation patterns
- **Best for**: Implementing domain-specific validation logic

#### 📚 [`readme_examples.exs`](readme_examples.exs)
- **What it covers**: All examples from the README for verification
- **Key concepts**: Complete feature overview
- **Best for**: Verifying installation and basic functionality

### Enhanced Feature Examples

#### 🚀 [`runtime_schema.exs`](runtime_schema.exs) ⭐ **NEW**
- **What it covers**: Dynamic schema creation at runtime
- **Key concepts**: Runtime schema generation, field definitions, dynamic validation
- **DSPy pattern**: `pydantic.create_model("DSPyProgramOutputs", **fields)`
- **Best for**: Creating schemas programmatically based on runtime requirements

**Key features demonstrated:**
- ✅ Basic runtime schema creation with field definitions
- ✅ Data validation against runtime schemas  
- ❌ Error handling and reporting
- 🏗️ Complex nested data structures
- 📋 JSON Schema generation
- 🔧 Dynamic schema modification
- 🔀 Conditional field requirements
- ⚙️ Different validation configurations
- ⚡ Performance characteristics

#### 🔧 [`type_adapter.exs`](type_adapter.exs) ⭐ **NEW**
- **What it covers**: Runtime type validation without schemas
- **Key concepts**: TypeAdapter system, type coercion, serialization
- **DSPy pattern**: `TypeAdapter(type(value)).validate_python(value)`
- **Best for**: One-off validations and dynamic type checking

**Key features demonstrated:**
- ✅ Basic type validation for primitive types
- 🔄 Type coercion capabilities
- 🏗️ Complex nested type structures
- 🔀 Union type handling
- 📤 Value serialization (dump)
- ♻️ Reusable TypeAdapter instances
- 📦 Batch validation for performance
- 📋 JSON Schema generation
- 🎯 Complex nested validation scenarios
- ⚡ Performance benchmarking

#### 🎁 [`wrapper_models.exs`](wrapper_models.exs) ⭐ **NEW**
- **What it covers**: Temporary single-field validation schemas
- **Key concepts**: Wrapper models, flexible input handling, factory patterns
- **DSPy pattern**: `create_model("Wrapper", value=(target_type, ...))`
- **Best for**: Complex type coercion and single-field validation

**Key features demonstrated:**
- ✅ Basic wrapper creation and validation
- ⚡ One-step wrapper validation for convenience
- 🔀 Flexible input handling (raw values, maps with atom/string keys)
- 📦 Multiple wrapper operations for complex forms
- 🏭 Wrapper factory pattern for reusable type definitions
- 🎯 Complex type wrappers (arrays, maps, unions)
- 📋 JSON Schema generation from wrappers
- 🔍 Wrapper introspection and information
- 🚨 Comprehensive error handling and validation
- ⚡ Performance optimization through wrapper reuse

#### 🚀 [`enhanced_validator.exs`](enhanced_validator.exs) ⭐ **NEW**
- **What it covers**: Universal validation interface across all Elixact features
- **Key concepts**: Enhanced validator, configuration-driven validation, pipelines
- **DSPy pattern**: Unified validation with dynamic configuration
- **Best for**: Complex applications with varying validation requirements

**Key features demonstrated:**
- 🎯 Universal validation interface (compiled, runtime, type specs)
- ⚙️ Configuration-driven validation behavior
- 🎁 Wrapper validation for single values
- 📦 Batch validation for multiple values
- 📋 Validation with simultaneous JSON schema generation
- 🤖 LLM provider-specific optimizations
- 🔄 Validation and transformation pipelines
- 🔍 Comprehensive validation reports for debugging
- 🚨 Error recovery and handling patterns
- ⚡ Performance benchmarking across approaches

#### ⚙️ [`advanced_config.exs`](advanced_config.exs) ⭐ **NEW**
- **What it covers**: Runtime configuration modification and presets
- **Key concepts**: Configuration system, builder pattern, presets
- **DSPy pattern**: `ConfigDict(extra="forbid", frozen=True)`
- **Best for**: Flexible validation behavior based on context

**Key features demonstrated:**
- 📝 Basic configuration creation from maps and keywords
- 🎛️ Predefined configuration presets for common scenarios
- 🔀 Configuration merging with frozen config behavior
- 🏗️ Fluent builder pattern for readable configuration
- 🔀 Conditional configuration based on environment
- 🎨 Preset application with builder customization
- 🎯 Purpose-built configurations for different use cases
- 🚨 Configuration validation and error handling
- 🔄 Configuration conversion to validation options
- 🧪 Real-world testing with different configurations

#### 🔗 [`json_schema_resolver.exs`](json_schema_resolver.exs) ⭐ **NEW**
- **What it covers**: Advanced JSON schema manipulation for LLM integration
- **Key concepts**: Reference resolution, schema flattening, provider optimization
- **DSPy pattern**: LLM-compatible schema generation
- **Best for**: Preparing schemas for different LLM providers

**Key features demonstrated:**
- 🔗 Basic JSON schema reference resolution ($ref expansion)
- 🏗️ Nested reference resolution with multiple levels
- 🔄 Circular reference detection and depth limiting
- 📄 Schema flattening for simplified structure
- 🤖 OpenAI structured output optimization
- 🧠 Anthropic-specific schema requirements
- 🚫 Provider-specific format removal
- ⚡ LLM optimization (description removal, union simplification)
- 🎯 Complex integration with runtime schemas
- 🚨 Error handling for malformed schemas
- ⚡ Performance benchmarking and optimization

#### 🔮 [`dspy_integration.exs`](dspy_integration.exs) ⭐ **NEW**
- **What it covers**: Complete DSPy integration patterns
- **Key concepts**: All DSPy patterns working together in realistic scenarios
- **DSPy pattern**: Complete DSPy program simulation
- **Best for**: Understanding how to build DSPy-style applications with Elixact

**Key features demonstrated:**
- 🏗️ Dynamic schema creation (create_model equivalent)
- 🔧 TypeAdapter for quick validation (TypeAdapter equivalent)
- 🎁 Wrapper models for complex coercion (Wrapper pattern)
- ⚙️ Configuration patterns for different LLM scenarios
- 🎯 Complete DSPy program simulation with validation
- 🤖 Provider-specific JSON schema optimization
- 🔄 Error recovery and retry patterns
- ⚡ Performance analysis for production deployment

## Running Examples

### All Examples
```bash
# Run all examples in sequence
for example in examples/*.exs; do
  echo "Running $(basename $example)..."
  mix run "$example"
  echo "---"
done
```

### Core Examples Only
```bash
mix run examples/basic_usage.exs
mix run examples/advanced_features.exs
mix run examples/custom_validation.exs
```

### Enhanced Features Only
```bash
mix run examples/runtime_schema.exs
mix run examples/type_adapter.exs  
mix run examples/wrapper_models.exs
mix run examples/enhanced_validator.exs
mix run examples/advanced_config.exs
mix run examples/json_schema_resolver.exs
mix run examples/dspy_integration.exs
```

### Specific Use Cases

#### DSPy Development
```bash
# Start with DSPy integration to see the big picture
mix run examples/dspy_integration.exs

# Then dive into specific features
mix run examples/runtime_schema.exs
mix run examples/type_adapter.exs
mix run examples/wrapper_models.exs
```

#### LLM Integration
```bash
# JSON schema generation and optimization
mix run examples/json_schema_resolver.exs

# Enhanced validation for LLM outputs
mix run examples/enhanced_validator.exs

# Configuration for different providers
mix run examples/advanced_config.exs
```

#### Performance Analysis
```bash
# Each enhanced example includes performance benchmarks
mix run examples/runtime_schema.exs | grep "Performance"
mix run examples/type_adapter.exs | grep "Performance" 
mix run examples/enhanced_validator.exs | grep "Performance"
```

## Example Categories

### By Complexity Level

**🟢 Beginner** (Start here)
- `basic_usage.exs` - Core concepts
- `runtime_schema.exs` - Dynamic schemas
- `type_adapter.exs` - Runtime validation

**🟡 Intermediate** 
- `advanced_features.exs` - Complex patterns
- `wrapper_models.exs` - Temporary schemas
- `advanced_config.exs` - Configuration system

**🔴 Advanced**
- `enhanced_validator.exs` - Universal interface
- `json_schema_resolver.exs` - LLM optimization
- `dspy_integration.exs` - Complete integration

### By Use Case

**📊 Data Validation**
- `basic_usage.exs` - Standard validation
- `custom_validation.exs` - Business logic
- `enhanced_validator.exs` - Advanced patterns

**🤖 LLM Integration**
- `json_schema_resolver.exs` - Schema optimization
- `dspy_integration.exs` - Complete DSPy patterns
- `enhanced_validator.exs` - Provider-specific validation

**⚡ Performance**
- `type_adapter.exs` - Fast type checking
- `wrapper_models.exs` - Efficient coercion
- `enhanced_validator.exs` - Batch validation

**🔧 Development Tools**
- `runtime_schema.exs` - Dynamic schema creation
- `advanced_config.exs` - Flexible configuration
- `wrapper_models.exs` - Quick prototyping

## Key Concepts by Example

| Concept | Examples That Cover It |
|---------|----------------------|
| **Schema Definition** | `basic_usage.exs`, `advanced_features.exs` |
| **Runtime Schemas** | `runtime_schema.exs`, `dspy_integration.exs` |
| **Type Validation** | `type_adapter.exs`, `enhanced_validator.exs` |
| **Type Coercion** | `wrapper_models.exs`, `type_adapter.exs` |
| **Configuration** | `advanced_config.exs`, `enhanced_validator.exs` |
| **JSON Schema** | `json_schema_resolver.exs`, `runtime_schema.exs` |
| **Error Handling** | All examples |
| **Performance** | All enhanced examples |
| **LLM Integration** | `dspy_integration.exs`, `json_schema_resolver.exs` |
| **DSPy Patterns** | `dspy_integration.exs`, `runtime_schema.exs`, `wrapper_models.exs` |

## Common Patterns

### Creating Dynamic Schemas
```elixir
# See: runtime_schema.exs, dspy_integration.exs
fields = [
  {:name, :string, [required: true, min_length: 2]},
  {:email, :string, [required: true, format: ~r/@/]}
]
schema = Elixact.Runtime.create_schema(fields)
```

### Quick Type Validation
```elixir
# See: type_adapter.exs, enhanced_validator.exs  
{:ok, validated} = Elixact.TypeAdapter.validate(:integer, "123", coerce: true)
```

### Wrapper Validation
```elixir
# See: wrapper_models.exs, dspy_integration.exs
{:ok, score} = Elixact.Wrapper.wrap_and_validate(:score, :integer, "85", 
  coerce: true, constraints: [gteq: 0, lteq: 100])
```

### Configuration-Driven Validation
```elixir
# See: advanced_config.exs, enhanced_validator.exs
config = Elixact.Config.preset(:production)
{:ok, validated} = Elixact.EnhancedValidator.validate(schema, data, config: config)
```

### LLM Schema Optimization
```elixir
# See: json_schema_resolver.exs, dspy_integration.exs
optimized = json_schema
|> Elixact.JsonSchema.Resolver.resolve_references()
|> Elixact.JsonSchema.Resolver.enforce_structured_output(provider: :openai)
```

## Tips for Learning

1. **Start Simple**: Begin with `basic_usage.exs` to understand core concepts
2. **Follow Use Cases**: Pick examples based on your specific needs (DSPy, LLM, validation)
3. **Read the Code**: Each example is heavily commented with explanations
4. **Experiment**: Modify the examples to test different scenarios
5. **Check Performance**: Most examples include performance benchmarks
6. **Understand Errors**: Examples demonstrate both success and failure cases

## Getting Help

- Each example includes comprehensive comments explaining the concepts
- Error messages in examples show common pitfalls and solutions
- Performance sections help you understand when to use each feature
- DSPy integration example shows real-world usage patterns

## Contributing Examples

When adding new examples:

1. Follow the established format with clear sections and comments
2. Include both success and failure scenarios  
3. Add performance benchmarks for new features
4. Provide practical, real-world use cases
5. Update this README with the new example information

---

**Made with Elixir** 💜 | **Enhanced for DSPy** 🔮
