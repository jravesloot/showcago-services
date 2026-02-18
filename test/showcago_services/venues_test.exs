defmodule ShowcagoServices.VenuesTest do
  use ShowcagoServices.DataCase, async: true

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Artist
  alias ShowcagoServices.Schema.Show
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

    test "setting schedule_html updates data_last_collected" do
      venue = create_venue!(%{name: "Lincoln Hall"})

      assert {:ok, %Venue{} = updated} =
               Venues.update_venue(venue, %{schedule_html: "<div>Upcoming shows</div>"})

      assert updated.schedule_html == "<div>Upcoming shows</div>"
      assert %DateTime{} = updated.data_last_collected
    end

    test "setting schedule_html on create sets data_last_collected" do
      assert {:ok, %Venue{} = venue} =
               Venues.create_venue(%{
                 name: "Sleeping Village",
                 schedule_html: "<ul><li>Show</li></ul>"
               })

      assert venue.schedule_html == "<ul><li>Show</li></ul>"
      assert %DateTime{} = venue.data_last_collected
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

  describe "schedule html collection" do
    test "collect_schedule_html/2 fetches and stores schedule html" do
      venue = create_venue!(%{name: "The Salt Shed", website: "https://example.com"})

      fetch_html_fun = fn _url -> {:ok, "<html>salt shed schedule</html>"} end

      assert {:ok, updated, :updated} =
               Venues.collect_schedule_html(venue, fetch_html_fun: fetch_html_fun, force: true)

      assert updated.schedule_html == "<html>salt shed schedule</html>"
      assert %DateTime{} = updated.data_last_collected
    end

    test "collect_schedule_html/2 skips when recently collected" do
      venue =
        create_venue!(%{
          name: "Metro",
          website: "https://example.com",
          data_last_collected: DateTime.utc_now(:second)
        })

      fetch_html_fun = fn _url ->
        flunk("fetch_html_fun should not be called when request is throttled")
      end

      assert {:ok, same_venue, :skipped} =
               Venues.collect_schedule_html(
                 venue,
                 fetch_html_fun: fetch_html_fun,
                 refresh_interval_seconds: 3_600
               )

      assert same_venue.id == venue.id
    end

    test "collect_salt_shed_schedule_data/1 returns not found error when missing" do
      assert {:error, :salt_shed_not_found} = Venues.collect_salt_shed_schedule_data(force: true)
    end

    test "collect_salt_shed_schedule_data/1 stores raw api payload" do
      venue = create_venue!(%{name: "The Salt Shed"})

      fetch_ticketmaster_events_fun = fn ->
        {:ok,
         [
           %{
             "name" => "Stereolab",
             "url" => "https://www.axs.com/events/123/stereolab-tickets",
             "dates" => %{"start" => %{"dateTime" => "2026-09-30T20:00:00-05:00"}}
           }
         ]}
      end

      assert {:ok, updated, :updated} =
               Venues.collect_salt_shed_schedule_data(
                 force: true,
                 fetch_ticketmaster_events_fun: fetch_ticketmaster_events_fun
               )

      assert updated.id == venue.id

      assert {:ok, payload} = Jason.decode(updated.schedule_html)
      assert payload["source"] == "salt_shed_ticketmaster_api"
      assert is_binary(payload["fetched_at"])
      assert is_list(payload["events"])
      assert Enum.any?(payload["events"], &(&1["name"] == "Stereolab"))
    end
  end

  describe "schedule html parsing" do
    test "creates matched shows from stored schedule html" do
      {:ok, artist} =
        %Artist{}
        |> Artist.changeset(%{name: "James Blake"})
        |> Repo.insert()

      venue =
        create_venue!(%{
          name: "The Salt Shed",
          schedule_html: """
          <html>
            <head>
              <script type=\"application/ld+json\">
                {"@context":"https://schema.org","@type":"MusicEvent","name":"James Blake with Special Guests","startDate":"2026-11-14T20:00:00-06:00","url":"https://www.saltshedchicago.com/event/james-blake"}
              </script>
            </head>
          </html>
          """
        })

      assert {:ok, result} = Venues.parse_schedule_html_and_create_shows(venue)
      assert result.parsed_events_count == 1
      assert result.matched_events_count == 1
      assert result.created_shows_count == 1

      show = Repo.one!(from s in Show, where: s.venue_id == ^venue.id)
      assert show.ticket_url == "https://www.saltshedchicago.com/event/james-blake"

      show_artist_ids =
        from(sa in "show_artists", where: sa.show_id == ^show.id, select: sa.artist_id)
        |> Repo.all()

      assert artist.id in show_artist_ids
    end

    test "is idempotent and does not create duplicate shows" do
      {:ok, _artist} =
        %Artist{}
        |> Artist.changeset(%{name: "Rosalia"})
        |> Repo.insert()

      venue =
        create_venue!(%{
          name: "The Salt Shed",
          schedule_html: """
          <script type=\"application/ld+json\">
            {"@type":"Event","name":"Rosalia","startDate":"2026-08-01T19:00:00Z","url":"https://example.com/rosalia"}
          </script>
          """
        })

      assert {:ok, first_run} = Venues.parse_schedule_html_and_create_shows(venue)
      assert first_run.created_shows_count == 1

      venue = Venues.get_venue!(venue.id)
      assert {:ok, second_run} = Venues.parse_schedule_html_and_create_shows(venue)
      assert second_run.created_shows_count == 0
    end

    test "returns error when schedule html is missing" do
      venue = create_venue!(%{name: "The Salt Shed"})

      assert {:error, :missing_schedule_html} = Venues.parse_schedule_html_and_create_shows(venue)
    end

    test "parses and creates shows through salt shed helper" do
      {:ok, _artist} =
        %Artist{}
        |> Artist.changeset(%{name: "Bongzilla"})
        |> Repo.insert()

      _venue =
        create_venue!(%{
          name: "The Salt Shed",
          schedule_html: """
          <script type=\"application/ld+json\">
            {"@type":"MusicEvent","name":"Bongzilla","startDate":"2026-12-01","url":"https://example.com/bongzilla"}
          </script>
          """
        })

      assert {:ok, result} = Venues.parse_salt_shed_schedule_html_and_create_shows()
      assert result.created_shows_count == 1
    end

    test "parses shows from stored salt shed api payload" do
      {:ok, artist} =
        %Artist{}
        |> Artist.changeset(%{name: "Stereolab"})
        |> Repo.insert()

      _venue =
        create_venue!(%{
          name: "The Salt Shed"
        })

      fetch_ticketmaster_events_fun = fn ->
        {:ok,
         [
           %{
             "name" => "Stereolab",
             "url" => "https://www.axs.com/events/123/stereolab-tickets",
             "dates" => %{"start" => %{"dateTime" => "2026-09-30T20:00:00-05:00"}}
           }
         ]}
      end

      assert {:ok, _updated, :updated} =
               Venues.collect_salt_shed_schedule_data(
                 force: true,
                 fetch_ticketmaster_events_fun: fetch_ticketmaster_events_fun
               )

      assert {:ok, result} = Venues.parse_salt_shed_schedule_html_and_create_shows()
      assert result.parsed_events_count == 1
      assert result.matched_events_count == 1
      assert result.created_shows_count == 1

      show = Repo.one!(from(s in Show))
      assert show.ticket_url == "https://www.axs.com/events/123/stereolab-tickets"

      show_artist_ids =
        from(sa in "show_artists", where: sa.show_id == ^show.id, select: sa.artist_id)
        |> Repo.all()

      assert artist.id in show_artist_ids
    end
  end

  defp create_venue!(attrs) do
    {:ok, venue} = Venues.create_venue(attrs)
    venue
  end
end
