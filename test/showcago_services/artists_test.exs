defmodule ShowcagoServices.ArtistsTest do
  use ShowcagoServices.DataCase, async: true

  alias ShowcagoServices.Artists
  alias ShowcagoServices.Schema.Artist
  alias ShowcagoServices.Repo

  describe "match_artists_in_text/2" do
    test "matches artist names embedded in longer event titles" do
      insert_artist!("Boris")
      insert_artist!("Bongzilla")
      insert_artist!("The Body")

      matches =
        Artists.match_artists_in_text(
          "Boris: Pink 20th Anniversary Tour 2025 w/ Bongzilla",
          limit: 10
        )

      names = Enum.map(matches, & &1.artist.name)

      assert "Boris" in names
      assert "Bongzilla" in names
      assert "The Body" not in names
    end

    test "does not match on partial-word false positives" do
      insert_artist!("Boris")

      matches = Artists.match_artists_in_text("This is a boring documentary", limit: 10)

      assert matches == []
    end

    test "returns an empty list for blank input" do
      insert_artist!("Boris")

      assert [] == Artists.match_artists_in_text("", limit: 10)
      assert [] == Artists.match_artists_in_text("   ", limit: 10)
    end

    test "returns an empty list for oversized input" do
      insert_artist!("Boris")

      oversized_text = String.duplicate("a", 501)

      assert [] == Artists.match_artists_in_text(oversized_text, limit: 10)
    end

    test "returns scored results with artist structs" do
      insert_artist!("Boris")

      [match | _] = Artists.match_artists_in_text("Boris at Metro", limit: 10)

      assert %Artist{} = match.artist
      assert is_float(match.score)
      assert match.score > 0.0
    end
  end

  defp insert_artist!(name) do
    %Artist{}
    |> Artist.changeset(%{name: name})
    |> Repo.insert!()
  end
end
