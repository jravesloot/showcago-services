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

  describe "list_artists/1 and count_artists/1" do
    test "paginates artist list with limit and offset" do
      for n <- 1..60 do
        insert_artist!("Artist #{String.pad_leading(Integer.to_string(n), 3, "0")}")
      end

      page_1 = Artists.list_artists(limit: 50, offset: 0)
      page_2 = Artists.list_artists(limit: 50, offset: 50)

      assert length(page_1) == 50
      assert length(page_2) == 10
      assert hd(page_1).name == "Artist 001"
      assert hd(page_2).name == "Artist 051"
    end

    test "counts artists with and without search" do
      insert_artist!("Boris")
      insert_artist!("Bongzilla")
      insert_artist!("The Body")

      assert Artists.count_artists() == 3
      assert Artists.count_artists(search: "bor") == 1
    end
  end

  defp insert_artist!(name) do
    %Artist{}
    |> Artist.changeset(%{name: name})
    |> Repo.insert!()
  end
end
