defmodule ShowcagoServices.Repo.Migrations.CreateShows do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:shows) do
      add :date, :utc_datetime, null: false
      add :doors_open, :time
      add :show_time, :time
      add :ticket_url, :string
      add :price_min, :decimal, precision: 10, scale: 2
      add :price_max, :decimal, precision: 10, scale: 2
      add :status, :string, default: "upcoming"
      add :notes, :text

      add :venue_id, references(:venues, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:shows, [:venue_id])
    create index(:shows, [:date])
    create index(:shows, [:status])

    create constraint(:shows, :shows_status_valid, check: "status IN ('upcoming', 'postponed', 'cancelled', 'past')")

    create table(:show_artists) do
      add :show_id, references(:shows, on_delete: :delete_all), null: false
      add :artist_id, references(:artists, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:show_artists, [:show_id])
    create index(:show_artists, [:artist_id])
    create unique_index(:show_artists, [:show_id, :artist_id])
  end
end
