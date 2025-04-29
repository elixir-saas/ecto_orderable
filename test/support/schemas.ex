defmodule Schemas.Set do
  use Ecto.Schema

  schema "sets" do
  end
end

defmodule Schemas.Item do
  use Ecto.Schema

  schema "items" do
    belongs_to :set, Schemas.Set
  end
end
