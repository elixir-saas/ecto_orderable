# Base schemas (no dependencies)

defmodule Schemas.Set do
  use Ecto.Schema

  schema "sets" do
  end
end

defmodule Schemas.User do
  use Ecto.Schema

  schema "users" do
    field(:name, :string)
  end
end

defmodule Schemas.Project do
  use Ecto.Schema

  schema "projects" do
    field(:name, :string)
  end
end

defmodule Schemas.Template do
  use Ecto.Schema

  schema "templates" do
    field(:name, :string)
    field(:position, :float)
  end
end

# Schemas with single dependency

defmodule Schemas.Item do
  use Ecto.Schema

  schema "items" do
    field(:position, :float)
    belongs_to(:set, Schemas.Set)
  end
end

defmodule Schemas.Status do
  use Ecto.Schema

  schema "statuses" do
    field(:name, :string)
    field(:position, :float)
    belongs_to(:project, Schemas.Project)
  end
end

# Schemas with multiple dependencies

defmodule Schemas.Task do
  use Ecto.Schema

  schema "tasks" do
    field(:title, :string)
    belongs_to(:status, Schemas.Status)
    belongs_to(:project, Schemas.Project)
  end
end

defmodule Schemas.TaskUser do
  use Ecto.Schema

  @primary_key false
  schema "task_users" do
    field(:position, :float)
    belongs_to(:task, Schemas.Task, primary_key: true)
    belongs_to(:user, Schemas.User, primary_key: true)
  end
end

defmodule Schemas.ProjectItem do
  @moduledoc """
  An item scoped to both a project AND a user.
  Each user has their own ordering of items within each project.
  """
  use Ecto.Schema

  schema "project_items" do
    field(:title, :string)
    field(:position, :float)
    belongs_to(:project, Schemas.Project)
    belongs_to(:user, Schemas.User)
  end
end

defmodule Schemas.UserTaskPosition do
  @moduledoc """
  A user's ordering of tasks. The status_id for scoping comes from
  the associated Task, not stored directly on this table.
  """
  use Ecto.Schema

  schema "user_task_positions" do
    field(:position, :float)
    belongs_to(:user, Schemas.User)
    belongs_to(:task, Schemas.Task)
  end
end
