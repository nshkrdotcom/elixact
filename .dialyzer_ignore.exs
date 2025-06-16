[
  # These functions work correctly in practice but Dialyzer can't analyze the complex call chains
  # involving Runtime.create_schema, Runtime.validate, and TypeAdapter calls
  ~r/lib\/elixact\/enhanced_validator\.ex:118.*Function validate_wrapped.* has no local return/,
  ~r/lib\/elixact\/enhanced_validator\.ex:121.*Function validate_wrapped.* has no local return/,
  ~r/lib\/elixact\/enhanced_validator\.ex:123.*Function validate_wrapped.* has no local return/,
  ~r/lib\/elixact\/wrapper\.ex:58.*Function create_wrapper.* has no local return/,
  ~r/lib\/elixact\/wrapper\.ex:69.*Function do_create_wrapper.* has no local return/,
  ~r/lib\/elixact\/wrapper\.ex:193.*Function wrap_and_validate.* has no local return/,
  ~r/lib\/elixact\/wrapper\.ex:224.*The created anonymous function has no local return/,
  ~r/lib\/elixact\/wrapper\.ex:317.*The created anonymous function has no local return/,
  ~r/lib\/elixact\/wrapper\.ex:459.*Function create_flexible_wrapper.* has no local return/,
  ~r/lib\/elixact\/wrapper\.ex:460.*Function create_flexible_wrapper.* has no local return/,
  # Extra range warning for validate_wrapped/4 due to try/rescue always returning a tuple
  ~r/lib\/elixact\/enhanced_validator\.ex:125.*extra_range/,
  # The type specification has too many types for the function.
  {"lib/elixact/enhanced_validator.ex", :extra_range, 125}
]
