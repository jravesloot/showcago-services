defmodule ShowcagoServices.VenuesTest do
  use ShowcagoServices.DataCase, async: true

  alias ShowcagoServices.Schema.Venue
  alias ShowcagoServices.Venues

  describe "list_venues/1 and count_venues/1" do
    test "paginates venues with limit and offset" do
      for n <- 1..60 do
        create_venue!(%{
          name: "Venue #{String.pad_leading(Integer.to_string(n), 3, "0")}",
          city: "Chicago",
          address: "#{n} Main St"
        })
      end

      page_1 = Venues.list_venues(limit: 50, offset: 0)
      page_2 = Venues.list_venues(limit: 50, offset: 50)

      assert length(page_1) == 50
      assert length(page_2) == 10
      assert hd(page_1).name == "Venue 001"
      assert hd(page_2).name == "Venue 051"
    end

    test "searches and counts venues by name, city, and address" do
      create_venue!(%{name: "Metro", city: "Chicago", address: "3730 N Clark St"})
      create_venue!(%{name: "House of Blues", city: "Chicago", address: "329 N Dearborn St"})
      create_venue!(%{name: "Red Rocks", city: "Morrison", address: "18300 W Alameda Pkwy"})

      assert Venues.count_venues() == 3
      assert Venues.count_venues(search: "Chicago") == 2
      assert Enum.any?(Venues.list_venues(search: "Clark"), &(&1.name == "Metro"))
      assert Enum.any?(Venues.list_venues(search: "Red Rocks"), &(&1.city == "Morrison"))
    end
  end

  describe "venue CRUD" do
    test "create_venue/1 inserts a venue" do
      attrs = %{name: "The Vic", city: "Chicago", address: "3145 N Sheffield Ave"}

      assert {:ok, %Venue{} = venue} = Venues.create_venue(attrs)
      assert venue.name == "The Vic"
      assert venue.city == "Chicago"
    end

    test "update_venue/2 updates an existing venue" do
      venue = create_venue!(%{name: "SubT", city: "Chicago"})

      assert {:ok, %Venue{} = updated} =
               Venues.update_venue(venue, %{website: "https://subt.net"})

      assert updated.website == "https://subt.net"
    end

    test "delete_venue/1 removes a venue" do
      venue = create_venue!(%{name: "Thalia Hall"})

      assert {:ok, %Venue{}} = Venues.delete_venue(venue)
      assert_raise Ecto.NoResultsError, fn -> Venues.get_venue!(venue.id) end
    end

    test "venue_changeset/2 returns a changeset and validates required fields" do
      changeset = Venues.venue_changeset(%Venue{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  defp create_venue!(attrs) do
    {:ok, venue} = Venues.create_venue(attrs)
    venue
  end
end
