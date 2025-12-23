defmodule Schemas.Set do
  use Ecto.Schema

  schema "sets" do
  end
end

defmodule Schemas.Item do
  use Ecto.Schema

  schema "items" do
    field(:order_index, :float)
    belongs_to(:set, Schemas.Set)
  end
end

defmodule Schemas.Task do
  use Ecto.Schema

  schema "tasks" do
    field(:title, :string)
  end
end

defmodule Schemas.User do
  use Ecto.Schema

  schema "users" do
    field(:name, :string)
  end
end

defmodule Schemas.TaskUser do
  use Ecto.Schema

  @primary_key false
  schema "task_users" do
    field(:order_index, :float)
    belongs_to(:task, Schemas.Task, primary_key: true)
    belongs_to(:user, Schemas.User, primary_key: true)
  end
end

defmodule Schemas.Template do
  use Ecto.Schema

  schema "templates" do
    field(:name, :string)
    field(:order_index, :float)
  end
end

defmodule Schemas.Project do
  use Ecto.Schema

  schema "projects" do
    field(:name, :string)
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
    field(:order_index, :float)
    belongs_to(:project, Schemas.Project)
    belongs_to(:user, Schemas.User)
  end
end
