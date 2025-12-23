defmodule EctoOrderable.TestRepo.Migrations.CreateUserTaskPositions do
  use Ecto.Migration

  def change do
    create table(:statuses) do
      add :name, :string
      add :position, :float
      add :project_id, references(:projects)
    end

    alter table(:tasks) do
      add :status_id, references(:statuses)
      add :project_id, references(:projects)
    end

    create table(:user_task_positions) do
      add :position, :float
      add :user_id, references(:users)
      add :task_id, references(:tasks)
    end

    create index(:user_task_positions, [:user_id, :task_id])
  end
end
