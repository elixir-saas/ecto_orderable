defmodule TestOrder do
  use EctoOrderable,
    repo: EctoOrderable.TestRepo,
    schema: Schemas.Item,
    scope: [:set_id]
end

defmodule TestTaskUserOrder do
  use EctoOrderable,
    repo: EctoOrderable.TestRepo,
    schema: Schemas.TaskUser,
    scope: [:user_id]
end

defmodule TestGlobalOrder do
  use EctoOrderable,
    repo: EctoOrderable.TestRepo,
    schema: Schemas.Template,
    scope: []
end

defmodule TestMultiScopeOrder do
  @moduledoc """
  Order module with multiple scope fields.
  Items are ordered per project per user.
  """
  use EctoOrderable,
    repo: EctoOrderable.TestRepo,
    schema: Schemas.ProjectItem,
    scope: [:project_id, :user_id]
end
