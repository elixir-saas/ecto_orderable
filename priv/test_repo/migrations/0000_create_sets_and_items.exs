defmodule EctoOrderable.TestRepo.Migrations.CreateSetsAndItems do
  use Ecto.Migration

  def change do
    create table(:sets)

    create table(:items) do
      add :set_id, references(:sets), null: false
      add :position, :float, null: false
    end
  end
end
