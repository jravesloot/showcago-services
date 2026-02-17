# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ShowcagoServices.Repo.insert!(%ShowcagoServices.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias ShowcagoServices.Schema.Artist
alias ShowcagoServices.Repo

artists_csv_path = Application.app_dir(:showcago_services, "priv/repo/seeds/artists.csv")

artists =
  artists_csv_path
  |> File.stream!([], :line)
  |> Stream.map(&String.trim/1)
  |> Stream.reject(&(&1 in ["", "Artist"]))
  |> Stream.map(fn line ->
    stripped_line =
      if String.starts_with?(line, "\"") and String.ends_with?(line, "\"") and
           String.length(line) >= 2 do
        String.slice(line, 1, String.length(line) - 2)
      else
        line
      end

    stripped_line
    |> String.replace("\"\"", "\"")
  end)
  |> Enum.uniq()

if artists == [] do
  IO.puts("No artists found in #{artists_csv_path}")
else
  now = DateTime.utc_now(:second)

  rows =
    Enum.map(artists, fn artist_name ->
      %{name: artist_name, inserted_at: now, updated_at: now}
    end)

  {inserted_count, _} =
    Repo.insert_all(Artist, rows,
      on_conflict: :nothing,
      conflict_target: [:name]
    )

  IO.puts("Seeded #{inserted_count} artists from #{artists_csv_path}")
end
