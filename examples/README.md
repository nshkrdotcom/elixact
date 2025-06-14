# Elixact Examples

This directory contains comprehensive examples demonstrating all features of Elixact.

## Running the Examples

Each example file can be run independently using Mix:

```bash
# Basic usage examples
mix run examples/basic_usage.exs

# Custom validation functions
mix run examples/custom_validation.exs

# Advanced features including object validation
mix run examples/advanced_features.exs

# README examples verification (tests all README code)
mix run examples/readme_examples.exs
```

## Example Files

### 1. `basic_usage.exs`
Demonstrates fundamental Elixact features with clear examples:
- Basic type validation (string, integer, boolean, atom)
- Type constraints (min_length, max_length, gt, lt, choices)  
- Complex types (arrays, maps, unions)
- Custom error messages
- Object types (fixed-key maps)

Each example shows both ✅ valid and ❌ invalid inputs with their results.

### 2. `custom_validation.exs`
Shows the power of custom validation functions:
- Email validation with business logic
- Password strength validation
- Value transformation (phone numbers, currency)
- Multiple validators on a single field
- Complex business rules (SKU validation, credit card validation)

### 3. `advanced_features.exs`
Covers advanced patterns and integration:
- Complex nested object structures
- Arrays of objects
- Union types with objects
- Business domain modeling
- Error handling patterns
- Complete integration examples

### 4. `readme_examples.exs` ⭐
**Verification suite that tests ALL README.md code examples line-for-line:**
- Basic Usage section examples
- Schema-Based Validation examples  
- All 5 Core Features examples
- Ensures README documentation accuracy
- Acts as a comprehensive test suite for documented functionality

This file guarantees that every code example in the README actually works as shown!

## Key Features Demonstrated

- **Custom Validation Functions**: Add business logic beyond basic constraints
- **Custom Error Messages**: Provide user-friendly error messages
- **Object Validation**: Validate fixed-key maps with field-by-field validation
- **Nested Structures**: Handle complex nested data structures
- **Value Transformation**: Modify values during validation (normalization, formatting)
- **Error Handling**: Different patterns for handling validation errors
- **Business Logic**: Real-world examples of domain-specific validation

## Use Cases Covered

- User registration forms
- E-commerce product validation
- Contact information validation
- Financial data validation
- Event system modeling
- API input validation
- Configuration validation