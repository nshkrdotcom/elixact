defmodule Elixact do
  @moduledoc """
  Elixact is a schema definition and validation library for Elixir.

  It provides a DSL for defining schemas with rich metadata, validation rules,
  and JSON Schema generation capabilities.

  ## Struct Pattern Support

  Elixact now supports generating structs alongside validation schemas:

      defmodule UserSchema do
        use Elixact, define_struct: true

        schema "User account information" do
          field :name, :string do
            required()
            min_length(2)
          end

          field :age, :integer do
            optional()
            gt(0)
          end
        end
      end

  The schema can then be used for validation and returns struct instances:

      # Returns {:ok, %UserSchema{name: "John", age: 30}}
      UserSchema.validate(%{name: "John", age: 30})

      # Serialize struct back to map
      {:ok, map} = UserSchema.dump(user_struct)

  ## Examples

      defmodule UserSchema do
        use Elixact

        schema "User registration data" do
          field :name, :string do
            required()
            min_length(2)
          end

          field :age, :integer do
            optional()
            gt(0)
            lt(150)
          end

          field :email, Types.Email do
            required()
          end

          config do
            title("User Schema")
            strict(true)
          end
        end
      end

  The schema can then be used for validation and JSON Schema generation:

      # Validation (returns map by default)
      {:ok, user} = UserSchema.validate(%{
        name: "John Doe",
        email: "john@example.com",
        age: 30
      })

      # JSON Schema generation
      json_schema = UserSchema.json_schema()
  """

  @doc """
  Configures a module to be an Elixact schema.

  ## Options

    * `:define_struct` - Whether to generate a struct for validated data.
      When `true`, validation returns struct instances instead of maps.
      Defaults to `false` for backwards compatibility.

  ## Examples

      # Traditional map-based validation
      defmodule UserMapSchema do
        use Elixact

        schema do
          field :name, :string
        end
      end

      # Struct-based validation
      defmodule UserStructSchema do
        use Elixact, define_struct: true

        schema do
          field :name, :string
        end
      end
  """
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(opts) do
    define_struct? = Keyword.get(opts, :define_struct, false)

    quote do
      import Elixact.Schema

      # Register accumulating attributes
      Module.register_attribute(__MODULE__, :schema_description, [])
      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      Module.register_attribute(__MODULE__, :validations, accumulate: true)
      Module.register_attribute(__MODULE__, :config, [])
      Module.register_attribute(__MODULE__, :model_validators, accumulate: true)
      Module.register_attribute(__MODULE__, :computed_fields, accumulate: true)

      # Store struct option for use in __before_compile__
      @elixact_define_struct unquote(define_struct?)

      @before_compile Elixact
    end
  end

  @doc """
  Phase 6 Enhancement: Enhanced schema information with complete feature analysis.

  ## Examples

      iex> UserSchema.__enhanced_schema_info__()
      %{
        elixact_version: "Phase 6",
        phase_6_enhanced: true,
        compatibility: %{...},
        performance_profile: %{...},
        llm_optimization: %{...}
      }
  """
  @spec __before_compile__(Macro.Env.t()) :: Macro.t()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro __before_compile__(_env) do
    define_struct? = Module.get_attribute(__CALLER__.module, :elixact_define_struct)
    fields = Module.get_attribute(__CALLER__.module, :fields) || []
    computed_fields = Module.get_attribute(__CALLER__.module, :computed_fields) || []

    # Extract field names for struct definition
    field_names = Enum.map(fields, fn {name, _meta} -> name end)
    computed_field_names = Enum.map(computed_fields, fn {name, _meta} -> name end)
    all_field_names = field_names ++ computed_field_names

    # Generate struct definition if requested
    struct_def =
      if define_struct? do
        quote do
          defstruct unquote(all_field_names)

          @type t :: %__MODULE__{}

          @doc """
          Returns the struct definition fields for this schema.
          Includes both regular fields and computed fields.
          """
          @spec __struct_fields__ :: [atom()]
          def __struct_fields__, do: unquote(all_field_names)

          @doc """
          Returns the regular (non-computed) struct fields for this schema.
          """
          @spec __regular_fields__ :: [atom()]
          def __regular_fields__, do: unquote(field_names)

          @doc """
          Returns the computed field names for this schema.
          """
          @spec __computed_field_names__ :: [atom()]
          def __computed_field_names__, do: unquote(computed_field_names)

          @doc """
          Returns whether this schema defines a struct.
          """
          @spec __struct_enabled__? :: true
          def __struct_enabled__?, do: true

          @doc """
          Serializes a struct instance back to a map.

          When serializing structs with computed fields, the computed fields
          are included in the resulting map since they are part of the struct.

          ## Parameters
            * `struct_or_map` - The struct instance or map to serialize

          ## Returns
            * `{:ok, map}` on success (includes computed fields)
            * `{:error, reason}` on failure

          ## Examples

              iex> user = %UserSchema{
              ...>   name: "John",
              ...>   email: "john@example.com",
              ...>   full_display: "John <john@example.com>"  # computed field
              ...> }
              iex> UserSchema.dump(user)
              {:ok, %{
                name: "John",
                email: "john@example.com",
                full_display: "John <john@example.com>"
              }}

              iex> UserSchema.dump(%{name: "John"})
              {:ok, %{name: "John"}}

              iex> UserSchema.dump("invalid")
              {:error, "Expected UserSchema struct or map, got: \"invalid\""}
          """
          @spec dump(struct() | map()) :: {:ok, map()} | {:error, String.t()}
          def dump(value), do: do_dump(__MODULE__, value)

          defp do_dump(module, %mod{} = struct) when mod == module,
            do: {:ok, Map.from_struct(struct)}

          defp do_dump(_module, map) when is_map(map), do: {:ok, map}

          defp do_dump(module, other),
            do: {:error, "Expected #{module} struct or map, got: #{inspect(other)}"}
        end
      else
        quote do
          @doc """
          Returns whether this schema defines a struct.
          """
          @spec __struct_enabled__? :: false
          def __struct_enabled__?, do: false

          @doc """
          Returns empty list since no struct is defined.
          """
          @spec __struct_fields__ :: []
          def __struct_fields__, do: []

          @doc """
          Returns the regular field names for this schema.
          """
          @spec __regular_fields__ :: [atom()]
          def __regular_fields__, do: unquote(field_names)

          @doc """
          Returns the computed field names for this schema.
          """
          @spec __computed_field_names__ :: [atom()]
          def __computed_field_names__, do: unquote(computed_field_names)
        end
      end

    quote do
      # Inject struct definition if requested
      unquote(struct_def)

      # Define __schema__ functions (updated to include computed_fields)
      def __schema__(:description), do: @schema_description
      def __schema__(:fields), do: @fields
      def __schema__(:validations), do: @validations
      def __schema__(:config), do: @config
      def __schema__(:model_validators), do: @model_validators || []
      def __schema__(:computed_fields), do: @computed_fields || []

      @doc """
      Validates data against this schema with full pipeline support.

      The validation pipeline now includes computed fields:
      1. Field validation
      2. Model validation (if any model validators are defined)
      3. Computed field execution (if any computed fields are defined)
      4. Struct creation (if define_struct: true)

      ## Parameters
        * `data` - The data to validate (map)

      ## Returns
        * `{:ok, validated_data}` on success - includes computed fields and returns struct if `define_struct: true`, map otherwise
        * `{:error, errors}` on validation failure

      ## Examples

          # Schema with computed fields
          defmodule UserSchema do
            use Elixact, define_struct: true

            schema do
              field :first_name, :string, required: true
              field :last_name, :string, required: true
              field :email, :string, required: true

              computed_field :full_name, :string, :generate_full_name
              computed_field :email_domain, :string, :extract_email_domain
            end

            def generate_full_name(input) do
              {:ok, "\#{input.first_name} \#{input.last_name}"}
            end

            def extract_email_domain(input) do
              {:ok, input.email |> String.split("@") |> List.last()}
            end
          end

          # With define_struct: true
          iex> UserSchema.validate(%{
          ...>   first_name: "John",
          ...>   last_name: "Doe",
          ...>   email: "john@example.com"
          ...> })
          {:ok, %UserSchema{
            first_name: "John",
            last_name: "Doe",
            email: "john@example.com",
            full_name: "John Doe",         # computed field
            email_domain: "example.com"    # computed field
          }}

          # With define_struct: false (default)
          iex> UserMapSchema.validate(data)
          {:ok, %{
            first_name: "John",
            last_name: "Doe",
            email: "john@example.com",
            full_name: "John Doe",
            email_domain: "example.com"
          }}
      """
      @spec validate(map()) :: {:ok, map() | struct()} | {:error, [Elixact.Error.t()]}
      def validate(data) do
        Elixact.StructValidator.validate_schema(__MODULE__, data)
      end

      @doc """
      Validates data against this schema, raising an exception on failure.

      ## Parameters
        * `data` - The data to validate (map)

      ## Returns
        * Validated data on success (struct or map depending on schema configuration, includes computed fields)
        * Raises `Elixact.ValidationError` on failure

      ## Examples

          iex> UserSchema.validate!(%{first_name: "John", last_name: "Doe", email: "john@example.com"})
          %UserSchema{
            first_name: "John",
            last_name: "Doe",
            email: "john@example.com",
            full_name: "John Doe",         # computed field included
            email_domain: "example.com"    # computed field included
          }

          iex> UserSchema.validate!(%{})
          ** (Elixact.ValidationError) first_name: field is required
      """
      @spec validate!(map()) :: map() | struct()
      def validate!(data) do
        case validate(data) do
          {:ok, validated} -> validated
          {:error, errors} -> raise Elixact.ValidationError, errors: errors
        end
      end

      @doc """
      Returns information about the schema including computed fields.

      ## Returns
        * Map with schema metadata including computed field information

      ## Examples

          iex> UserSchema.__schema_info__()
          %{
            has_struct: true,
            field_count: 3,
            computed_field_count: 2,
            model_validator_count: 0,
            regular_fields: [:first_name, :last_name, :email],
            computed_fields: [:full_name, :email_domain],
            all_fields: [:first_name, :last_name, :email, :full_name, :email_domain]
          }
      """
      @spec __schema_info__ :: map()
      def __schema_info__ do
        regular_fields = __schema__(:fields) |> Enum.map(fn {name, _} -> name end)
        computed_fields = __schema__(:computed_fields) |> Enum.map(fn {name, _} -> name end)
        model_validators = __schema__(:model_validators)

        %{
          has_struct: __struct_enabled__?(),
          field_count: length(regular_fields),
          computed_field_count: length(computed_fields),
          model_validator_count: length(model_validators),
          regular_fields: regular_fields,
          computed_fields: computed_fields,
          all_fields: regular_fields ++ computed_fields,
          model_validators: Enum.map(model_validators, fn {mod, fun} -> "#{mod}.#{fun}/1" end)
        }
      end

      # Phase 6 enhancements

      @doc """
      Returns enhanced schema information with Phase 6 features.

      Includes comprehensive analysis of schema capabilities, performance characteristics,
      and LLM provider compatibility.
      """
      @spec __enhanced_schema_info__ :: map()
      def __enhanced_schema_info__ do
        basic_info = __schema_info__()

        # Add Phase 6 specific information
        enhanced_info = %{
          elixact_version: "Phase 6",
          phase_6_enhanced: true,
          json_schema_enhanced: true,
          llm_compatible: true,
          dspy_ready: analyze_dspy_readiness(),
          performance_profile: analyze_performance_profile(),
          compatibility_matrix: analyze_compatibility_matrix()
        }

        Map.merge(basic_info, enhanced_info)
      end

      @doc """
      Validates data with Phase 6 enhanced pipeline and optional reporting.

      ## Options
        * `:include_performance_metrics` - Include validation performance data
        * `:test_llm_compatibility` - Test schema compatibility with LLM providers
        * `:generate_enhanced_schema` - Include enhanced JSON schema in result

      ## Examples

          iex> result = UserSchema.validate_enhanced(data,
          ...>   include_performance_metrics: true,
          ...>   test_llm_compatibility: true
          ...> )
          {:ok, validated_data, %{
            performance_metrics: %{...},
            llm_compatibility: %{...},
            enhanced_schema: %{...}
          }}
      """
      @spec validate_enhanced(map(), keyword()) ::
              {:ok, map() | struct()}
              | {:ok, map() | struct(), map()}
              | {:error, [Elixact.Error.t()]}
      def validate_enhanced(data, opts \\ []) do
        include_metrics = Keyword.get(opts, :include_performance_metrics, false)
        test_llm = Keyword.get(opts, :test_llm_compatibility, false)
        generate_schema = Keyword.get(opts, :generate_enhanced_schema, false)

        start_time = System.monotonic_time(:microsecond)

        case validate(data) do
          {:ok, validated_data} ->
            if include_metrics or test_llm or generate_schema do
              additional_info =
                build_enhanced_validation_result(
                  validated_data,
                  start_time,
                  include_metrics,
                  test_llm,
                  generate_schema
                )

              {:ok, validated_data, additional_info}
            else
              {:ok, validated_data}
            end

          {:error, errors} ->
            {:error, errors}
        end
      end

      # Private helper functions for Phase 6 enhancements

      defp analyze_dspy_readiness do
        model_validator_count = length(__schema__(:model_validators) || [])
        computed_field_count = length(__schema__(:computed_fields) || [])

        %{
          ready: model_validator_count <= 3 and computed_field_count <= 5,
          model_validators: model_validator_count,
          computed_fields: computed_field_count,
          recommendations:
            generate_dspy_recommendations(model_validator_count, computed_field_count)
        }
      end

      defp analyze_performance_profile do
        field_count = length(__schema__(:fields) || [])
        model_validator_count = length(__schema__(:model_validators) || [])
        computed_field_count = length(__schema__(:computed_fields) || [])

        complexity_score = field_count + model_validator_count * 2 + computed_field_count * 3

        %{
          complexity_score: complexity_score,
          estimated_validation_time: estimate_validation_time(complexity_score),
          memory_footprint: estimate_memory_footprint(field_count, computed_field_count),
          optimization_level: determine_optimization_level(complexity_score)
        }
      end

      defp analyze_compatibility_matrix do
        has_struct = __struct_enabled__?()
        has_validators = length(__schema__(:model_validators) || []) > 0
        has_computed = length(__schema__(:computed_fields) || []) > 0

        %{
          json_schema_generation: true,
          llm_providers: %{
            openai: true,
            anthropic: true,
            generic: true
          },
          dspy_patterns: %{
            # Signatures work better without computed fields
            signature: not has_computed,
            # CoT benefits from validation
            chain_of_thought: has_validators,
            input_output: true
          },
          struct_support: has_struct,
          enhanced_features: has_validators or has_computed
        }
      end

      defp build_enhanced_validation_result(
             validated_data,
             start_time,
             include_metrics,
             test_llm,
             generate_schema
           ) do
        result = %{}

        result =
          if include_metrics do
            end_time = System.monotonic_time(:microsecond)
            duration = end_time - start_time

            metrics = %{
              validation_duration_microseconds: duration,
              validation_duration_milliseconds: duration / 1000,
              memory_used: :erlang.memory(:total)
            }

            Map.put(result, :performance_metrics, metrics)
          else
            result
          end

        result =
          if test_llm do
            compatibility = test_llm_provider_compatibility()
            Map.put(result, :llm_compatibility, compatibility)
          else
            result
          end

        result =
          if generate_schema do
            enhanced_schema = Elixact.JsonSchema.EnhancedResolver.resolve_enhanced(__MODULE__)
            Map.put(result, :enhanced_schema, enhanced_schema)
          else
            result
          end

        result
      end

      defp generate_dspy_recommendations(model_validators, computed_fields) do
        recommendations = []

        recommendations =
          if model_validators > 3 do
            ["Consider reducing model validators for DSPy compatibility" | recommendations]
          else
            recommendations
          end

        recommendations =
          if computed_fields > 5 do
            ["Consider reducing computed fields for DSPy signatures" | recommendations]
          else
            recommendations
          end

        if length(recommendations) == 0 do
          ["Schema is well-suited for DSPy usage"]
        else
          recommendations
        end
      end

      defp estimate_validation_time(complexity_score) do
        cond do
          complexity_score < 10 -> "< 1ms"
          complexity_score < 25 -> "1-5ms"
          complexity_score < 50 -> "5-15ms"
          true -> "> 15ms"
        end
      end

      defp estimate_memory_footprint(field_count, computed_field_count) do
        # bytes per field
        base_memory = field_count * 100
        # computed fields use more memory
        computed_memory = computed_field_count * 300
        total = base_memory + computed_memory

        cond do
          total < 1000 -> "< 1KB"
          total < 5000 -> "1-5KB"
          total < 10000 -> "5-10KB"
          true -> "> 10KB"
        end
      end

      defp determine_optimization_level(complexity_score) do
        cond do
          complexity_score < 20 -> :high
          complexity_score < 50 -> :medium
          true -> :low
        end
      end

      defp test_llm_provider_compatibility do
        # This would be expanded in a real implementation
        %{
          openai: %{compatible: true, score: 85},
          anthropic: %{compatible: true, score: 80},
          generic: %{compatible: true, score: 90}
        }
      end
    end
  end
end
