defmodule ShowcagoServices.Repo.Migrations.AddIgnoredToShows do
  use Ecto.Migration

  def change do
    alter table(:shows) do
      add :ignored, :boolean, default: false, null: false
    end

    create index(:shows, [:ignored])
  end
end
