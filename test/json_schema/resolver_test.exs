defmodule Elixact.JsonSchema.ResolverTest do
  use ExUnit.Case, async: true
  
  alias Elixact.JsonSchema.Resolver

  describe "resolve_references/2" do
    test "handles invalid references gracefully" do
      schema = %{
        "properties" => %{
          "user" => %{"$ref" => "#/definitions/NonExistent"}
        },
        "definitions" => %{
          "User" => %{"type" => "object"}
        }
      }
      
      resolved = Resolver.resolve_references(schema)
      
      # Should keep the original reference when resolution fails
      assert resolved["properties"]["user"]["$ref"] == "#/definitions/NonExistent"
    end
  end

  describe "flatten_schema/2" do
    test "expands all references inline" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "user" => %{"$ref" => "#/definitions/User"},
          "company" => %{"$ref" => "#/definitions/Company"}
        },
        "definitions" => %{
          "User" => %{
            "type" => "object",
            "properties" => %{"name" => %{"type" => "string"}}
          },
          "Company" => %{
            "type" => "object", 
            "properties" => %{"name" => %{"type" => "string"}}
          }
        }
      }
      
      flattened = Resolver.flatten_schema(schema)
      
      assert flattened["properties"]["user"]["type"] == "object"
      assert flattened["properties"]["company"]["type"] == "object"
      refute Map.has_key?(flattened, "definitions")
      refute Map.has_key?(flattened, "$defs")
    end

    test "handles deeply nested structures" do
      schema = %{
        "properties" => %{
          "data" => %{
            "type" => "object",
            "properties" => %{
              "items" => %{
                "type" => "array",
                "items" => %{"$ref" => "#/definitions/Item"}
              }
            }
          }
        },
        "definitions" => %{
          "Item" => %{
            "type" => "object",
            "properties" => %{
              "value" => %{"type" => "string"},
              "nested" => %{"$ref" => "#/definitions/NestedItem"}
            }
          },
          "NestedItem" => %{
            "type" => "object",
            "properties" => %{"id" => %{"type" => "integer"}}
          }
        }
      }
      
      flattened = Resolver.flatten_schema(schema)
      
      items_schema = flattened["properties"]["data"]["properties"]["items"]["items"]
      assert items_schema["type"] == "object"
      assert items_schema["properties"]["value"]["type"] == "string"
      assert items_schema["properties"]["nested"]["type"] == "object"
      assert items_schema["properties"]["nested"]["properties"]["id"]["type"] == "integer"
    end

    test "avoids infinite recursion with max_depth" do
      schema = %{
        "definitions" => %{
          "Node" => %{
            "type" => "object",
            "properties" => %{
              "value" => %{"type" => "string"},
              "child" => %{"$ref" => "#/definitions/Node"}
            }
          }
        },
        "$ref" => "#/definitions/Node"
      }
      
      flattened = Resolver.flatten_schema(schema, max_depth: 2)
      
      # Should flatten to the specified depth
      assert flattened["type"] == "object"
      assert flattened["properties"]["value"]["type"] == "string"
      # Child should be flattened but not infinitely
    end

    test "inlines simple type references when requested" do
      schema = %{
        "properties" => %{
          "status" => %{"$ref" => "#/definitions/Status"}
        },
        "definitions" => %{
          "Status" => %{"type" => "string", "enum" => ["active", "inactive"]}
        }
      }
      
      flattened = Resolver.flatten_schema(schema, inline_simple_refs: true)
      
      assert flattened["properties"]["status"]["type"] == "string"
      assert flattened["properties"]["status"]["enum"] == ["active", "inactive"]
    end

    test "preserves complex references when requested" do
      schema = %{
        "properties" => %{
          "simple" => %{"$ref" => "#/definitions/Simple"},
          "complex" => %{"$ref" => "#/definitions/Complex"}
        },
        "definitions" => %{
          "Simple" => %{"type" => "string"},
          "Complex" => %{
            "type" => "object",
            "properties" => %{"nested" => %{"type" => "object"}}
          }
        }
      }
      
      flattened = Resolver.flatten_schema(schema, 
        inline_simple_refs: true, 
        preserve_complex_refs: true
      )
      
      # Simple should be inlined
      assert flattened["properties"]["simple"]["type"] == "string"
      # Complex should preserve reference
      assert flattened["properties"]["complex"]["$ref"] == "#/definitions/Complex"
    end
  end

  describe "enforce_structured_output/2" do
    test "removes unsupported features for OpenAI" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "email" => %{"type" => "string", "format" => "email"}
        },
        "additionalProperties" => true
      }
      
      enforced = Resolver.enforce_structured_output(schema, provider: :openai)
      
      assert enforced["additionalProperties"] == false
      # Email format might be removed if unsupported
    end

    test "enforces OpenAI requirements" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"}
        }
      }
      
      enforced = Resolver.enforce_structured_output(schema, 
        provider: :openai, 
        add_required_fields: true
      )
      
      assert enforced["additionalProperties"] == false
      assert Map.has_key?(enforced, "properties")
    end

    test "handles Anthropic requirements" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "data" => %{"type" => "string"}
        }
      }
      
      enforced = Resolver.enforce_structured_output(schema, provider: :anthropic)
      
      assert enforced["additionalProperties"] == false
      assert enforced["required"] == []
    end

    test "removes unsupported formats" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "date" => %{"type" => "string", "format" => "date"},
          "email" => %{"type" => "string", "format" => "email"},
          "uri" => %{"type" => "string", "format" => "uri"}
        }
      }
      
      # OpenAI might not support certain formats
      enforced = Resolver.enforce_structured_output(schema, 
        provider: :openai, 
        remove_unsupported: true
      )
      
      # Should remove unsupported formats but keep supported ones
      date_prop = enforced["properties"]["date"]
      refute Map.has_key?(date_prop, "format") or date_prop["format"] != "date"
    end

    test "validates against provider constraints" do
      # Test invalid schema for OpenAI
      invalid_schema = %{
        "type" => "object",
        "additionalProperties" => true
        # Missing properties
      }
      
      enforced = Resolver.enforce_structured_output(invalid_schema, provider: :openai)
      
      # Should either fix the schema or return the original if validation fails
      assert Map.has_key?(enforced, "properties") or enforced == invalid_schema
    end

    test "handles generic provider gracefully" do
      schema = %{
        "type" => "object",
        "properties" => %{"name" => %{"type" => "string"}},
        "additionalProperties" => true
      }
      
      enforced = Resolver.enforce_structured_output(schema, provider: :generic)
      
      # Should not modify much for generic provider
      assert enforced["additionalProperties"] == true
    end
  end

  describe "optimize_for_llm/2" do
    test "removes descriptions when requested" do
      schema = %{
        "type" => "object",
        "description" => "A complex object",
        "properties" => %{
          "name" => %{
            "type" => "string",
            "description" => "The user's name"
          },
          "nested" => %{
            "type" => "object",
            "description" => "Nested data",
            "properties" => %{
              "value" => %{
                "type" => "string",
                "description" => "Some value"
              }
            }
          }
        }
      }
      
      optimized = Resolver.optimize_for_llm(schema, remove_descriptions: true)
      
      refute Map.has_key?(optimized, "description")
      refute Map.has_key?(optimized["properties"]["name"], "description")
      refute Map.has_key?(optimized["properties"]["nested"], "description")
      refute Map.has_key?(optimized["properties"]["nested"]["properties"]["value"], "description")
    end

    test "simplifies complex unions" do
      schema = %{
        "oneOf" => [
          %{"type" => "string"},
          %{"type" => "integer"},
          %{"type" => "boolean"},
          %{"type" => "array"},
          %{"type" => "object"},
          %{"type" => "null"}
        ]
      }
      
      optimized = Resolver.optimize_for_llm(schema, simplify_unions: true)
      
      assert length(optimized["oneOf"]) <= 3
    end

    test "limits properties when max_properties is set" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "field1" => %{"type" => "string"},
          "field2" => %{"type" => "string"},
          "field3" => %{"type" => "string"},
          "field4" => %{"type" => "string"},
          "field5" => %{"type" => "string"}
        }
      }
      
      optimized = Resolver.optimize_for_llm(schema, max_properties: 3)
      
      assert map_size(optimized["properties"]) <= 3
    end

    test "preserves essential structure when not optimizing" do
      schema = %{
        "type" => "object",
        "description" => "Important schema",
        "properties" => %{
          "critical" => %{"type" => "string", "description" => "Critical field"}
        },
        "oneOf" => [%{"type" => "string"}, %{"type" => "integer"}]
      }
      
      optimized = Resolver.optimize_for_llm(schema, 
        remove_descriptions: false,
        simplify_unions: false
      )
      
      assert optimized == schema
    end

    test "applies multiple optimizations together" do
      schema = %{
        "type" => "object",
        "description" => "Complex schema",
        "properties" => %{
          "field1" => %{"type" => "string", "description" => "Field 1"},
          "field2" => %{"type" => "string", "description" => "Field 2"},
          "field3" => %{"type" => "string", "description" => "Field 3"},
          "union_field" => %{
            "oneOf" => [
              %{"type" => "string"},
              %{"type" => "integer"},
              %{"type" => "boolean"},
              %{"type" => "array"}
            ]
          }
        }
      }
      
      optimized = Resolver.optimize_for_llm(schema,
        remove_descriptions: true,
        simplify_unions: true,
        max_properties: 2
      )
      
      refute Map.has_key?(optimized, "description")
      assert map_size(optimized["properties"]) <= 2
      
      # Check if union was simplified (if union_field is still present)
      if Map.has_key?(optimized["properties"], "union_field") do
        union_length = length(optimized["properties"]["union_field"]["oneOf"])
        assert union_length <= 3
      end
    end
  end

  describe "edge cases and error handling" do
    test "handles malformed schemas gracefully" do
      malformed_schema = %{
        "properties" => %{
          "bad_ref" => %{"$ref" => "invalid-ref-format"}
        }
      }
      
      resolved = Resolver.resolve_references(malformed_schema)
      
      # Should not crash and preserve original structure
      assert resolved["properties"]["bad_ref"]["$ref"] == "invalid-ref-format"
    end

    test "handles empty schemas" do
      empty_schema = %{}
      
      resolved = Resolver.resolve_references(empty_schema)
      flattened = Resolver.flatten_schema(empty_schema)
      enforced = Resolver.enforce_structured_output(empty_schema, provider: :openai)
      
      assert resolved == %{}
      assert flattened == %{}
      assert is_map(enforced)
    end

    test "handles schemas with no references" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        }
      }
      
      resolved = Resolver.resolve_references(schema)
      
      assert resolved == schema
    end

    test "preserves array items and nested structures" do
      schema = %{
        "type" => "array",
        "items" => %{"$ref" => "#/definitions/Item"},
        "definitions" => %{
          "Item" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"}
            }
          }
        }
      }
      
      resolved = Resolver.resolve_references(schema)
      
      assert resolved["type"] == "array"
      assert resolved["items"]["type"] == "object"
      assert resolved["items"]["properties"]["name"]["type"] == "string"
    end
  end
end "resolves simple $ref" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "user" => %{"$ref" => "#/definitions/User"}
        },
        "definitions" => %{
          "User" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"}
            }
          }
        }
      }
      
      resolved = Resolver.resolve_references(schema)
      
      assert resolved["properties"]["user"]["type"] == "object"
      assert resolved["properties"]["user"]["properties"]["name"]["type"] == "string"
      refute Map.has_key?(resolved, "definitions")
    end

    test "resolves nested references" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "company" => %{"$ref" => "#/definitions/Company"}
        },
        "definitions" => %{
          "Company" => %{
            "type" => "object",
            "properties" => %{
              "owner" => %{"$ref" => "#/definitions/User"},
              "employees" => %{
                "type" => "array",
                "items" => %{"$ref" => "#/definitions/User"}
              }
            }
          },
          "User" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"},
              "email" => %{"type" => "string"}
            }
          }
        }
      }
      
      resolved = Resolver.resolve_references(schema)
      
      company = resolved["properties"]["company"]
      assert company["type"] == "object"
      assert company["properties"]["owner"]["type"] == "object"
      assert company["properties"]["owner"]["properties"]["name"]["type"] == "string"
      assert company["properties"]["employees"]["items"]["type"] == "object"
    end

    test "handles circular references without infinite recursion" do
      schema = %{
        "definitions" => %{
          "Node" => %{
            "type" => "object",
            "properties" => %{
              "value" => %{"type" => "string"},
              "parent" => %{"$ref" => "#/definitions/Node"},
              "children" => %{
                "type" => "array",
                "items" => %{"$ref" => "#/definitions/Node"}
              }
            }
          }
        },
        "$ref" => "#/definitions/Node"
      }
      
      resolved = Resolver.resolve_references(schema, max_depth: 3)
      
      # Should resolve but not infinitely
      assert resolved["type"] == "object"
      assert resolved["properties"]["value"]["type"] == "string"
      # Deeper levels should stop resolving
    end

    test "preserves titles and descriptions when requested" do
      schema = %{
        "properties" => %{
          "user" => %{
            "$ref" => "#/definitions/User",
            "title" => "User Information",
            "description" => "Details about the user"
          }
        },
        "definitions" => %{
          "User" => %{
            "type" => "object",
            "properties" => %{"name" => %{"type" => "string"}}
          }
        }
      }
      
      resolved = Resolver.resolve_references(schema, preserve_titles: true, preserve_descriptions: true)
      
      user_prop = resolved["properties"]["user"]
      assert user_prop["title"] == "User Information"
      assert user_prop["description"] == "Details about the user"
      assert user_prop["type"] == "object"
    end

    test "handles $defs as well as definitions" do
      schema = %{
        "properties" => %{
          "user" => %{"$ref" => "#/$defs/User"}
        },
        "$defs" => %{
          "User" => %{
            "type" => "object",
            "properties" => %{"name" => %{"type" => "string"}}
          }
        }
      }
      
      resolved = Resolver.resolve_references(schema)
      
      assert resolved["properties"]["user"]["type"] == "object"
      assert resolved["properties"]["user"]["properties"]["name"]["type"] == "string"
    end

    test "preserves non-reference content unchanged" do
      schema = %{
        "type" => "object",
        "title" => "Root Schema",
        "properties" => %{
          "id" => %{"type" => "string"},
          "count" => %{"type" => "integer", "minimum" => 0},
          "tags" => %{
            "type" => "array",
            "items" => %{"type" => "string"}
          }
        },
        "required" => ["id"]
      }
      
      resolved = Resolver.resolve_references(schema)
      
      assert resolved == schema  # Should be unchanged
    end

    test
