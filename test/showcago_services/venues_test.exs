defmodule ShowcagoServices.VenuesTest do
  use ShowcagoServices.DataCase, async: true

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Artist
  alias ShowcagoServices.Schema.Show
  alias ShowcagoServices.Schema.Venue
  alias ShowcagoServices.Schema.VenueSource
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
    test "get_venue_by_name/1 returns matching venue or nil" do
      venue = create_venue!(%{name: "Lincoln Hall", city: "Chicago"})

      assert %Venue{id: venue_id} = Venues.get_venue_by_name("Lincoln Hall")
      assert venue_id == venue.id
      assert Venues.get_venue_by_name("Missing Venue") == nil
    end

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

  describe "schedule payload collection" do
    test "collect_schedule_payload_for_source/2 returns unknown source error" do
      assert {:error, :unknown_source} =
               Venues.collect_schedule_payload_for_source("unknown_source", force: true)
    end

    test "collect_schedule_payload_for_source/2 collects thalia via source key" do
      venue = create_venue!(%{name: "Thalia Hall"})
      insert_source_config!(venue, "thalia_hall_ticketmaster")

      fetch_ticketmaster_events_fun = fn ->
        {:ok,
         [
           %{
             "name" => "Hanumankind",
             "url" => "https://www.ticketweb.com/event/hanumankind-thalia-hall-tickets/123",
             "dates" => %{"start" => %{"dateTime" => "2026-03-03T01:00:00Z"}}
           }
         ]}
      end

      assert {:ok, updated, :updated} =
               Venues.collect_schedule_payload_for_source("thalia_hall_ticketmaster",
                 force: true,
                 fetch_ticketmaster_events_fun: fetch_ticketmaster_events_fun
               )

      assert updated.id == venue.id
    end

    test "collect_schedule_payload_for_source/2 returns not found for salt shed when missing" do
      assert {:error, :salt_shed_not_found} =
               Venues.collect_schedule_payload_for_source("salt_shed_ticketmaster", force: true)
    end

    test "collect_schedule_payload_for_source/2 stores raw api payload for salt shed" do
      venue = create_venue!(%{name: "The Salt Shed"})
      insert_source_config!(venue, "salt_shed_ticketmaster")

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
               Venues.collect_schedule_payload_for_source("salt_shed_ticketmaster",
                 force: true,
                 fetch_ticketmaster_events_fun: fetch_ticketmaster_events_fun
               )

      assert updated.id == venue.id

      source_row =
        Repo.get_by!(VenueSource, venue_id: venue.id, source_key: "salt_shed_ticketmaster")

      assert {:ok, payload} = Jason.decode(source_row.raw_payload)
      assert payload["source"] == "salt_shed_ticketmaster_api"
      assert is_binary(payload["fetched_at"])
      assert is_list(payload["events"])
      assert Enum.any?(payload["events"], &(&1["name"] == "Stereolab"))

      assert source_row.payload_format == "json"
      assert %DateTime{} = source_row.fetched_at
    end

    test "collect_schedule_payload_for_source/2 returns not found for thalia when missing" do
      assert {:error, :thalia_hall_not_found} =
               Venues.collect_schedule_payload_for_source("thalia_hall_ticketmaster", force: true)
    end

    test "collect_schedule_payload_for_source/2 stores raw api payload for thalia" do
      venue = create_venue!(%{name: "Thalia Hall"})
      insert_source_config!(venue, "thalia_hall_ticketmaster")

      fetch_ticketmaster_events_fun = fn ->
        {:ok,
         [
           %{
             "name" => "Hanumankind",
             "url" => "https://www.ticketweb.com/event/hanumankind-thalia-hall-tickets/123",
             "dates" => %{"start" => %{"dateTime" => "2026-03-03T01:00:00Z"}}
           }
         ]}
      end

      assert {:ok, updated, :updated} =
               Venues.collect_schedule_payload_for_source("thalia_hall_ticketmaster",
                 force: true,
                 fetch_ticketmaster_events_fun: fetch_ticketmaster_events_fun
               )

      assert updated.id == venue.id

      source_row =
        Repo.get_by!(VenueSource,
          venue_id: venue.id,
          source_key: "thalia_hall_ticketmaster"
        )

      assert {:ok, payload} = Jason.decode(source_row.raw_payload)
      assert payload["source"] == "thalia_hall_ticketmaster_api"
      assert is_binary(payload["fetched_at"])
      assert is_list(payload["events"])
      assert Enum.any?(payload["events"], &(&1["name"] == "Hanumankind"))
      assert updated.id == venue.id

      assert source_row.payload_format == "json"
      assert %DateTime{} = source_row.fetched_at
    end

    test "collect_schedule_payload_for_source/2 skips when recently collected for thalia" do
      venue =
        create_venue!(%{
          name: "Thalia Hall"
        })

      insert_source_payload!(
        venue,
        "thalia_hall_ticketmaster",
        ~s({"source":"thalia_hall_ticketmaster_api","events":[]}),
        "json"
      )

      fetch_ticketmaster_events_fun = fn ->
        flunk("fetch_ticketmaster_events_fun should not be called when request is throttled")
      end

      assert {:ok, same_venue, :skipped} =
               Venues.collect_schedule_payload_for_source("thalia_hall_ticketmaster",
                 fetch_ticketmaster_events_fun: fetch_ticketmaster_events_fun,
                 refresh_interval_seconds: 21_600
               )

      assert same_venue.id == venue.id
    end

    test "parses shows from stored thalia hall api payload" do
      {:ok, artist} =
        %Artist{}
        |> Artist.changeset(%{name: "Hanumankind"})
        |> Repo.insert()

      _venue =
        create_venue!(%{
          name: "Thalia Hall"
        })

      venue = Repo.get_by!(Venue, name: "Thalia Hall")
      insert_source_config!(venue, "thalia_hall_ticketmaster")

      fetch_ticketmaster_events_fun = fn ->
        {:ok,
         [
           %{
             "name" => "Hanumankind",
             "url" => "https://www.ticketweb.com/event/hanumankind-thalia-hall-tickets/123",
             "dates" => %{"start" => %{"dateTime" => "2026-03-03T01:00:00Z"}}
           }
         ]}
      end

      assert {:ok, _updated, :updated} =
               Venues.collect_schedule_payload_for_source("thalia_hall_ticketmaster",
                 force: true,
                 fetch_ticketmaster_events_fun: fetch_ticketmaster_events_fun
               )

      assert {:ok, result} =
               Venues.parse_schedule_payload_and_create_shows_for_source("thalia_hall_ticketmaster")

      assert result.parsed_events_count == 1
      assert result.matched_events_count == 1
      assert result.created_shows_count == 1

      show = Repo.one!(from(s in Show))

      assert show.ticket_url ==
               "https://www.ticketweb.com/event/hanumankind-thalia-hall-tickets/123"

      show_artist_ids = Repo.all(from(sa in "show_artists", where: sa.show_id == ^show.id, select: sa.artist_id))

      assert artist.id in show_artist_ids
    end
  end

  describe "schedule payload parsing" do
    test "parse_schedule_payload_and_create_shows_for_source/1 returns unknown source error" do
      assert {:error, :unknown_source} =
               Venues.parse_schedule_payload_and_create_shows_for_source("unknown_source")
    end

    test "creates matched shows from stored schedule payload" do
      {:ok, artist} =
        %Artist{}
        |> Artist.changeset(%{name: "James Blake"})
        |> Repo.insert()

      venue =
        create_venue!(%{
          name: "The Salt Shed",
          website: "https://example.com"
        })

      insert_source_payload!(
        venue,
        "salt_shed_ticketmaster",
        """
        {"source":"salt_shed_ticketmaster_api","events":[{"name":"James Blake with Special Guests","url":"https://www.saltshedchicago.com/event/james-blake","dates":{"start":{"dateTime":"2026-11-14T20:00:00-06:00"}}}]}
        """,
        "json"
      )

      assert {:ok, result} = Venues.parse_schedule_payload_and_create_shows(venue)
      assert result.parsed_events_count == 1
      assert result.matched_events_count == 1
      assert result.created_shows_count == 1

      show = Repo.one!(from s in Show, where: s.venue_id == ^venue.id)
      assert show.ticket_url == "https://www.saltshedchicago.com/event/james-blake"

      show_artist_ids = Repo.all(from(sa in "show_artists", where: sa.show_id == ^show.id, select: sa.artist_id))

      assert artist.id in show_artist_ids
    end

    test "attaches multiple matched artists from a single event title" do
      {:ok, artist_1} =
        %Artist{}
        |> Artist.changeset(%{name: "Jesus and Mary Chain"})
        |> Repo.insert()

      {:ok, artist_2} =
        %Artist{}
        |> Artist.changeset(%{name: "Tortoise"})
        |> Repo.insert()

      venue =
        create_venue!(%{
          name: "The Salt Shed",
          website: "https://example.com"
        })

      insert_source_payload!(
        venue,
        "salt_shed_ticketmaster",
        """
        {"source":"salt_shed_ticketmaster_api","events":[{"name":"Warm Love Cool Dreams- The Jesus and Mary Chain, Tortoise, Smerz +More","url":"https://www.saltshedchicago.com/event/warm-love-cool-dreams","dates":{"start":{"dateTime":"2026-11-14T20:00:00-06:00"}}}]}
        """,
        "json"
      )

      assert {:ok, result} = Venues.parse_schedule_payload_and_create_shows(venue)
      assert result.parsed_events_count == 1
      assert result.matched_events_count == 1
      assert result.created_shows_count == 1

      show = Repo.one!(from s in Show, where: s.venue_id == ^venue.id)

      show_artist_ids = Repo.all(from(sa in "show_artists", where: sa.show_id == ^show.id, select: sa.artist_id))

      assert artist_1.id in show_artist_ids
      assert artist_2.id in show_artist_ids
    end

    test "is idempotent and does not create duplicate shows" do
      {:ok, _artist} =
        %Artist{}
        |> Artist.changeset(%{name: "Rosalia"})
        |> Repo.insert()

      venue =
        create_venue!(%{
          name: "The Salt Shed",
          website: "https://example.com"
        })

      insert_source_payload!(
        venue,
        "salt_shed_ticketmaster",
        """
        {"source":"salt_shed_ticketmaster_api","events":[{"name":"Rosalia","url":"https://example.com/rosalia","dates":{"start":{"dateTime":"2026-08-01T19:00:00Z"}}}]}
        """,
        "json"
      )

      assert {:ok, first_run} = Venues.parse_schedule_payload_and_create_shows(venue)
      assert first_run.created_shows_count == 1

      venue = Venues.get_venue!(venue.id)
      assert {:ok, second_run} = Venues.parse_schedule_payload_and_create_shows(venue)
      assert second_run.created_shows_count == 0
    end

    test "returns source_not_configured when no source is configured" do
      venue = create_venue!(%{name: "The Salt Shed"})

      assert {:error, :source_not_configured} =
               Venues.parse_schedule_payload_and_create_shows(venue)
    end

    test "parses and creates shows through salt shed helper" do
      {:ok, _artist} =
        %Artist{}
        |> Artist.changeset(%{name: "Bongzilla"})
        |> Repo.insert()

      venue =
        create_venue!(%{
          name: "The Salt Shed",
          website: "https://example.com"
        })

      insert_source_payload!(
        venue,
        "salt_shed_ticketmaster",
        """
        {"source":"salt_shed_ticketmaster_api","events":[{"name":"Bongzilla","url":"https://example.com/bongzilla","dates":{"start":{"dateTime":"2026-12-01T00:00:00Z"}}}]}
        """,
        "json"
      )

      assert {:ok, result} =
               Venues.parse_schedule_payload_and_create_shows_for_source("salt_shed_ticketmaster")

      assert result.created_shows_count == 1
    end

    test "parses using source when venue name does not match known names" do
      {:ok, _artist} =
        %Artist{}
        |> Artist.changeset(%{name: "Stereolab"})
        |> Repo.insert()

      venue =
        create_venue!(%{
          name: "Salt Shed Custom",
          website: "https://example.com"
        })

      insert_source_payload!(
        venue,
        "salt_shed_ticketmaster",
        """
        {"source":"salt_shed_ticketmaster_api","events":[{"name":"Stereolab","url":"https://www.axs.com/events/123/stereolab-tickets","dates":{"start":{"dateTime":"2026-09-30T20:00:00-05:00"}}}]}
        """,
        "json"
      )

      assert {:ok, result} =
               Venues.parse_schedule_payload_and_create_shows(venue,
                 source: "salt_shed_ticketmaster"
               )

      assert result.parsed_events_count == 1
      assert result.created_shows_count == 1
    end

    test "parse_schedule_payload_and_create_shows_for_source/1 returns not found for thalia when missing" do
      assert {:error, :thalia_hall_not_found} =
               Venues.parse_schedule_payload_and_create_shows_for_source("thalia_hall_ticketmaster")
    end

    test "parse_schedule_payload_and_create_shows_for_source/1 parses salt shed source" do
      {:ok, artist} =
        %Artist{}
        |> Artist.changeset(%{name: "Stereolab"})
        |> Repo.insert()

      venue =
        create_venue!(%{
          name: "The Salt Shed"
        })

      insert_source_payload!(
        venue,
        "salt_shed_ticketmaster",
        """
        {"source":"salt_shed_ticketmaster_api","events":[{"name":"Stereolab","url":"https://www.axs.com/events/123/stereolab-tickets","dates":{"start":{"dateTime":"2026-09-30T20:00:00-05:00"}}}]}
        """,
        "json"
      )

      assert {:ok, result} =
               Venues.parse_schedule_payload_and_create_shows_for_source("salt_shed_ticketmaster")

      assert result.parsed_events_count == 1
      assert result.created_shows_count == 1

      show = Repo.one!(from(s in Show))
      assert show.ticket_url == "https://www.axs.com/events/123/stereolab-tickets"

      show_artist_ids = Repo.all(from(sa in "show_artists", where: sa.show_id == ^show.id, select: sa.artist_id))

      assert artist.id in show_artist_ids
    end

    test "collect_schedule_payload_for_source/2 returns not found for aragon ballroom when missing" do
      assert {:error, :aragon_ballroom_not_found} =
               Venues.collect_schedule_payload_for_source("aragon_ballroom_ticketmaster",
                 force: true
               )
    end

    test "collect_schedule_payload_for_source/2 stores raw api payload for aragon ballroom" do
      venue = create_venue!(%{name: "Aragon Ballroom"})
      insert_source_config!(venue, "aragon_ballroom_ticketmaster")

      fetch_ticketmaster_events_fun = fn ->
        {:ok,
         [
           %{
             "name" => "Bad Bunny",
             "url" => "https://www.ticketmaster.com/event/aragon-ballroom-bad-bunny/456",
             "dates" => %{"start" => %{"dateTime" => "2026-07-15T01:00:00Z"}}
           }
         ]}
      end

      assert {:ok, updated, :updated} =
               Venues.collect_schedule_payload_for_source("aragon_ballroom_ticketmaster",
                 force: true,
                 fetch_ticketmaster_events_fun: fetch_ticketmaster_events_fun
               )

      assert updated.id == venue.id

      source_row =
        Repo.get_by!(VenueSource,
          venue_id: venue.id,
          source_key: "aragon_ballroom_ticketmaster"
        )

      assert {:ok, payload} = Jason.decode(source_row.raw_payload)
      assert payload["source"] == "aragon_ballroom_ticketmaster_api"
      assert is_binary(payload["fetched_at"])
      assert is_list(payload["events"])
      assert Enum.any?(payload["events"], &(&1["name"] == "Bad Bunny"))

      assert source_row.payload_format == "json"
      assert %DateTime{} = source_row.fetched_at
    end

    test "collect_schedule_payload_for_source/2 skips when recently collected for aragon ballroom" do
      venue = create_venue!(%{name: "Aragon Ballroom"})

      insert_source_payload!(
        venue,
        "aragon_ballroom_ticketmaster",
        ~s({"source":"aragon_ballroom_ticketmaster_api","events":[]}),
        "json"
      )

      fetch_ticketmaster_events_fun = fn ->
        flunk("fetch_ticketmaster_events_fun should not be called when request is throttled")
      end

      assert {:ok, same_venue, :skipped} =
               Venues.collect_schedule_payload_for_source("aragon_ballroom_ticketmaster",
                 fetch_ticketmaster_events_fun: fetch_ticketmaster_events_fun,
                 refresh_interval_seconds: 3_600
               )

      assert same_venue.id == venue.id
    end

    test "parses shows from stored aragon ballroom api payload" do
      {:ok, artist} =
        %Artist{}
        |> Artist.changeset(%{name: "Bad Bunny"})
        |> Repo.insert()

      _venue = create_venue!(%{name: "Aragon Ballroom"})

      venue = Repo.get_by!(Venue, name: "Aragon Ballroom")
      insert_source_config!(venue, "aragon_ballroom_ticketmaster")

      fetch_ticketmaster_events_fun = fn ->
        {:ok,
         [
           %{
             "name" => "Bad Bunny",
             "url" => "https://www.ticketmaster.com/event/aragon-ballroom-bad-bunny/456",
             "dates" => %{"start" => %{"dateTime" => "2026-07-15T01:00:00Z"}}
           }
         ]}
      end

      assert {:ok, _updated, :updated} =
               Venues.collect_schedule_payload_for_source("aragon_ballroom_ticketmaster",
                 force: true,
                 fetch_ticketmaster_events_fun: fetch_ticketmaster_events_fun
               )

      assert {:ok, result} =
               Venues.parse_schedule_payload_and_create_shows_for_source("aragon_ballroom_ticketmaster")

      assert result.parsed_events_count == 1
      assert result.matched_events_count == 1
      assert result.created_shows_count == 1

      show = Repo.one!(from(s in Show))
      assert show.ticket_url == "https://www.ticketmaster.com/event/aragon-ballroom-bad-bunny/456"

      show_artist_ids =
        Repo.all(from(sa in "show_artists", where: sa.show_id == ^show.id, select: sa.artist_id))

      assert artist.id in show_artist_ids
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

      venue = Repo.get_by!(Venue, name: "The Salt Shed")
      insert_source_config!(venue, "salt_shed_ticketmaster")

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
               Venues.collect_schedule_payload_for_source("salt_shed_ticketmaster",
                 force: true,
                 fetch_ticketmaster_events_fun: fetch_ticketmaster_events_fun
               )

      assert {:ok, result} =
               Venues.parse_schedule_payload_and_create_shows_for_source("salt_shed_ticketmaster")

      assert result.parsed_events_count == 1
      assert result.matched_events_count == 1
      assert result.created_shows_count == 1

      show = Repo.one!(from(s in Show))
      assert show.ticket_url == "https://www.axs.com/events/123/stereolab-tickets"

      show_artist_ids = Repo.all(from(sa in "show_artists", where: sa.show_id == ^show.id, select: sa.artist_id))

      assert artist.id in show_artist_ids
    end
  end

  defp create_venue!(attrs) do
    {:ok, venue} = Venues.create_venue(attrs)
    venue
  end

  defp insert_source_payload!(venue, source_key, payload, payload_format) do
    %VenueSource{}
    |> VenueSource.changeset(%{
      venue_id: venue.id,
      source_key: source_key,
      raw_payload: payload,
      payload_format: payload_format,
      fetched_at: DateTime.utc_now(:second),
      enabled: true
    })
    |> Repo.insert!()
  end

  defp insert_source_config!(venue, source_key) do
    %VenueSource{}
    |> VenueSource.changeset(%{
      venue_id: venue.id,
      source_key: source_key,
      enabled: true
    })
    |> Repo.insert!()
  end
end
