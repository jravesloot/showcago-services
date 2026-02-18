defmodule ShowcagoServices.Repo.Migrations.AddScheduleFieldsToVenues do
  use Ecto.Migration

  def change do
    alter table(:venues) do
      add :schedule_html, :text
      add :data_last_collected, :utc_datetime
    end
  end
end
