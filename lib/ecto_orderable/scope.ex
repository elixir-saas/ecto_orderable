defmodule EctoOrderable.Scope do
  @moduledoc false

  @doc """
  Resolves scope values from various input types.

  Returns a keyword list of `{field, value}` pairs.
  """
  def resolve(_item_or_scope, _schema, []) do
    []
  end

  def resolve(item_or_scope, schema, scope_fields) do
    cond do
      # Item struct - extract scope fields
      is_struct(item_or_scope, schema) ->
        Enum.map(scope_fields, fn field -> {field, Map.fetch!(item_or_scope, field)} end)

      # Keyword list - use directly
      is_list(item_or_scope) and Keyword.keyword?(item_or_scope) ->
        Enum.map(scope_fields, fn field ->
          {field, Keyword.fetch!(item_or_scope, field)}
        end)

      # Parent struct - map :id to first scope field
      is_struct(item_or_scope) ->
        [first_scope_field | _] = scope_fields
        [{first_scope_field, item_or_scope.id}]

      true ->
        raise ArgumentError,
              "Expected an item struct, keyword list, or parent struct, got: #{inspect(item_or_scope)}"
    end
  end
end
