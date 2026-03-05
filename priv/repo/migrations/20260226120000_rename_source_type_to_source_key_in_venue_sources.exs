defmodule ShowcagoServices.Repo.Migrations.RenameSourceTypeToSourceKeyInVenueSources do
  @moduledoc false
  use Ecto.Migration

  def up do
    rename table(:venue_sources), :source_type, to: :source_key

    execute(
      "ALTER INDEX venue_sources_venue_id_source_type_index RENAME TO venue_sources_venue_id_source_key_index",
      "ALTER INDEX venue_sources_venue_id_source_key_index RENAME TO venue_sources_venue_id_source_type_index"
    )

    execute(
      "ALTER INDEX venue_sources_source_type_index RENAME TO venue_sources_source_key_index",
      "ALTER INDEX venue_sources_source_key_index RENAME TO venue_sources_source_type_index"
    )
  end

  def down do
    rename table(:venue_sources), :source_key, to: :source_type

    execute(
      "ALTER INDEX venue_sources_venue_id_source_key_index RENAME TO venue_sources_venue_id_source_type_index",
      "ALTER INDEX venue_sources_venue_id_source_type_index RENAME TO venue_sources_venue_id_source_key_index"
    )

    execute(
      "ALTER INDEX venue_sources_source_key_index RENAME TO venue_sources_source_type_index",
      "ALTER INDEX venue_sources_source_type_index RENAME TO venue_sources_source_key_index"
    )
  end
end
