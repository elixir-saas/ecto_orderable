defmodule EctoOrderable.TestRepo.Migrations.CreateManyToManyTables do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :title, :string
    end

    create table(:users) do
      add :name, :string
    end

    # Join table with composite primary key
    create table(:task_users, primary_key: false) do
      add :task_id, references(:tasks), null: false, primary_key: true
      add :user_id, references(:users), null: false, primary_key: true
      add :position, :float, null: false
    end

    create unique_index(:task_users, [:task_id, :user_id])
  end
end
