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
alias ShowcagoServices.Schema.Venue
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

venues_csv_path = Application.app_dir(:showcago_services, "priv/repo/seeds/venues.csv")

empty_to_nil = fn value ->
  if value == "" do
    nil
  else
    value
  end
end

venues =
  venues_csv_path
  |> File.stream!([], :line)
  |> Stream.map(&String.trim/1)
  |> Stream.reject(&(&1 in ["", "Name,Address,City,State,ZipCode,Website"]))
  |> Stream.map(fn line ->
    [name, address, city, state, zip_code, website] = String.split(line, ",", parts: 6)

    %{
      name: name,
      address: empty_to_nil.(address),
      city: empty_to_nil.(city),
      state: empty_to_nil.(state),
      zip_code: empty_to_nil.(zip_code),
      website: empty_to_nil.(website)
    }
  end)
  |> Enum.uniq_by(& &1.name)

if venues == [] do
  IO.puts("No venues found in #{venues_csv_path}")
else
  now = DateTime.utc_now(:second)

  rows =
    Enum.map(venues, fn venue ->
      Map.merge(venue, %{inserted_at: now, updated_at: now})
    end)

  {inserted_count, _} =
    Repo.insert_all(Venue, rows,
      on_conflict: :nothing,
      conflict_target: [:name]
    )

  IO.puts("Seeded #{inserted_count} venues from #{venues_csv_path}")
end
