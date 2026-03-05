defmodule ShowcagoServices.Repo.Migrations.AddArtistNameTrigramIndex do
  @moduledoc false
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    execute("CREATE EXTENSION IF NOT EXISTS unaccent")

    execute("""
    CREATE OR REPLACE FUNCTION immutable_unaccent(text)
    RETURNS text
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE
    AS $$
      SELECT public.unaccent($1)
    $$
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS artists_name_trgm_idx
    ON artists
    USING gin (lower(immutable_unaccent(name)) gin_trgm_ops)
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS artists_name_trgm_idx")
    execute("DROP FUNCTION IF EXISTS immutable_unaccent(text)")
  end
end
