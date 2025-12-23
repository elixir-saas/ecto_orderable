defmodule EctoOrderable.TestRepo.Migrations.CreateProjectItems do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :name, :string
    end

    create table(:project_items) do
      add :title, :string
      add :order_index, :float
      add :project_id, references(:projects)
      add :user_id, references(:users)
    end

    create index(:project_items, [:project_id, :user_id])
  end
end
