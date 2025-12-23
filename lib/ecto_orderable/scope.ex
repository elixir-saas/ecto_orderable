defmodule EctoOrderable.Scope do
  @moduledoc false

  import Ecto.Query

  @doc """
  Applies scope to a query by adding joins and where clauses.

  ## Parameters

    * `query` - The Ecto query to modify
    * `scope_values` - Keyword list of `{field, value}` pairs from `resolve/4`
    * `scope_join` - Keyword list mapping fields to `{JoinedSchema, :foreign_key}` tuples

  """
  def apply(query, scope_values, scope_join \\ []) do
    query
    |> apply_joins(scope_join)
    |> apply_wheres(scope_values, scope_join)
  end

  defp apply_joins(query, scope_join) do
    Enum.reduce(scope_join, query, fn {_field, {joined_schema, foreign_key}}, q ->
      [joined_pk | _] = joined_schema.__schema__(:primary_key)

      join(q, :inner, [s], joined in ^joined_schema,
        on: field(s, ^foreign_key) == field(joined, ^joined_pk),
        as: ^joined_schema
      )
    end)
  end

  defp apply_wheres(query, scope_values, scope_join) do
    Enum.reduce(scope_values, query, fn {field, value}, q ->
      case Keyword.get(scope_join, field) do
        nil ->
          where(q, [s], field(s, ^field) == ^value)

        {joined_schema, _foreign_key} ->
          where(q, [{^joined_schema, joined}], field(joined, ^field) == ^value)
      end
    end)
  end

  @doc """
  Resolves scope values from various input types.

  Returns a keyword list of `{field, value}` pairs.

  ## Parameters

    * `item_or_scope` - An item struct, keyword list, or parent struct
    * `schema` - The Ecto schema module
    * `scope_fields` - List of scope field names
    * `scope_join` - Optional keyword list mapping fields to `{JoinedSchema, :foreign_key}` tuples

  """
  def resolve(item_or_scope, schema, scope_fields, scope_join \\ [])

  def resolve(_item_or_scope, _schema, [], _scope_join) do
    []
  end

  def resolve(item_or_scope, schema, scope_fields, scope_join) do
    cond do
      # Item struct - extract scope fields (some may come from joined schemas)
      is_struct(item_or_scope, schema) ->
        Enum.map(scope_fields, fn field ->
          case Keyword.get(scope_join, field) do
            nil ->
              # Direct field on schema
              {field, Map.fetch!(item_or_scope, field)}

            {_joined_schema, foreign_key} ->
              # Field comes from a joined schema - find the association by foreign key
              association = find_association_by_foreign_key(schema, foreign_key)

              case Map.get(item_or_scope, association) do
                %Ecto.Association.NotLoaded{} ->
                  raise ArgumentError,
                        "Association #{inspect(association)} must be preloaded to resolve #{inspect(field)}. " <>
                          "Either preload the association or pass scope as a keyword list."

                nil ->
                  raise ArgumentError,
                        "Association #{inspect(association)} is nil, cannot resolve #{inspect(field)}"

                associated ->
                  {field, Map.fetch!(associated, field)}
              end
          end
        end)

      # Keyword list - use directly (user provides all values)
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

  defp find_association_by_foreign_key(schema, foreign_key) do
    # Find the association that uses this foreign key
    schema.__schema__(:associations)
    |> Enum.find_value(fn assoc_name ->
      assoc = schema.__schema__(:association, assoc_name)

      if assoc.owner_key == foreign_key do
        assoc_name
      end
    end) ||
      raise ArgumentError,
            "Could not find association with foreign key #{inspect(foreign_key)} on #{inspect(schema)}"
  end
end
