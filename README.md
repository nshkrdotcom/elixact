# Elixact

Elixact is a schema definition and validation library for Elixir with JSON Schema support.

Similar to Pydantic in Python.

## Features

- Rich schema DSL
- Type validation
- JSON Schema generation
- Custom types
- Nested schemas
- Field constraints
- Structured error messages

## Installation

Add `elixact` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elixact, "~> 0.1.0"}
  ]
end
```

## Usage

### Defining Schemas

```elixir
defmodule UserSchema do
  use Elixact

  schema "User account information" do
    field :name, :string do
      description "User's full name"
      example "John Doe"
      required true
      min_length 2
    end

    field :age, :integer do
      description "User's age in years"
      optional true
      gt 0
      lt 150
    end

    field :email, Types.Email do
      description "User's email address"
      required true
    end

    config do
      title "User Schema"
      strict true
    end
  end
end
```

### Validation

```elixir
# Validate data
case UserSchema.validate(data) do
  {:ok, validated} ->
    # Use validated data

  {:error, errors} ->
    # Handle validation errors
    Enum.each(errors, &IO.puts(Error.format(&1)))
end

# Or use bang version
validated = UserSchema.validate!(data)
```

### JSON Schema Generation

```elixir
# Generate JSON Schema
json_schema = UserSchema.json_schema()

# Use with JSON Schema validator
json = Jason.encode!(json_schema)
```

### Custom Types

```elixir
defmodule Types.Email do
  use Elixact.Type

  def type_definition do
    Types.string()
    |> Types.with_constraints([
      format: ~r/^[^\s]+@[^\s]+$/
    ])
  end

  def json_schema do
    %{
      "type" => "string",
      "format" => "email",
      "pattern" => "^[^\\s]+@[^\\s]+$"
    }
  end
end
```

## Documentation

Full documentation can be found at [https://hexdocs.pm/elixact](https://hexdocs.pm/elixact).

## License

MIT License. See LICENSE file for details.
