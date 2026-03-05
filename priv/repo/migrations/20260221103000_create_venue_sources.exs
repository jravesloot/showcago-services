defmodule ShowcagoServices.Repo.Migrations.CreateVenueSources do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:venue_sources) do
      add :venue_id, references(:venues, on_delete: :delete_all), null: false
      add :source_type, :string, null: false
      add :raw_payload, :text
      add :payload_format, :string
      add :fetched_at, :utc_datetime
      add :enabled, :boolean, null: false, default: true
      add :last_error, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:venue_sources, [:venue_id, :source_type])
    create index(:venue_sources, [:source_type])
  end
end
