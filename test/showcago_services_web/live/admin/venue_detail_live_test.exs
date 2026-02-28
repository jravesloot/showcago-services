defmodule ShowcagoServicesWeb.Admin.VenueDetailLiveTest do
  use ShowcagoServicesWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Show
  alias ShowcagoServices.Schema.VenueSource
  alias ShowcagoServices.Venues

  setup :register_and_log_in_admin_user

  test "renders venue sources and raw payload", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    %VenueSource{}
    |> VenueSource.changeset(%{
      venue_id: venue.id,
      source_key: "salt_shed_ticketmaster",
      raw_payload: "<div>Upcoming show</div>",
      payload_format: "html",
      fetched_at: DateTime.utc_now(:second),
      enabled: true
    })
    |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    assert has_element?(view, "#venue-sources-list")
    assert has_element?(view, "#venue-shows")
    assert render(view) =~ "Upcoming show"
    assert has_element?(view, ~s(a[href="/admin/venues/#{venue.id}/edit"]))
  end

  test "renders source last collected from latest non-nil fetched_at", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    collected_at = ~U[2026-02-21 18:30:00Z]

    %VenueSource{}
    |> VenueSource.changeset(%{
      venue_id: venue.id,
      source_key: "salt_shed_ticketmaster",
      raw_payload: "<div>Older payload</div>",
      payload_format: "html",
      fetched_at: collected_at,
      enabled: true
    })
    |> Repo.insert!()

    %VenueSource{}
    |> VenueSource.changeset(%{
      venue_id: venue.id,
      source_key: "thalia_hall_ticketmaster",
      raw_payload: "<div>Newer payload with nil timestamp</div>",
      payload_format: "html",
      fetched_at: nil,
      enabled: true
    })
    |> Repo.insert!()

    expected_label =
      collected_at
      |> DateTime.shift_zone!("America/Chicago")
      |> Calendar.strftime("%A, %B %-d, %Y %I:%M %p")
      |> Kernel.<>(" CT")

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    assert has_element?(view, "dt", "Source Last Collected")
    assert render(view) =~ expected_label
    refute render(view) =~ "Never"
  end

  test "renders shows for the current venue", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    {:ok, other_venue} =
      Venues.create_venue(%{
        name: "Metro",
        website: "https://metrochicago.com"
      })

    %Show{}
    |> Show.changeset(%{
      date: DateTime.add(DateTime.utc_now(:second), 86_400, :second),
      venue_id: venue.id,
      notes: "Venue Show"
    })
    |> Repo.insert!()

    %Show{}
    |> Show.changeset(%{
      date: DateTime.add(DateTime.utc_now(:second), 172_800, :second),
      venue_id: other_venue.id,
      notes: "Other Venue Show"
    })
    |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    assert has_element?(view, "#venue-shows")
    assert has_element?(view, "li", "Venue Show")
    refute has_element?(view, "li", "Other Venue Show")
  end

  test "hides ignored shows by default on venue detail", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    %Show{}
    |> Show.changeset(%{
      date: DateTime.add(DateTime.utc_now(:second), 86_400, :second),
      venue_id: venue.id,
      notes: "Ignored Venue Show",
      ignored: true
    })
    |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    refute has_element?(view, "li", "Ignored Venue Show")
    assert has_element?(view, "#toggle-ignored-venue-shows", "Show ignored shows")
  end

  test "shows ignored shows when toggled on venue detail", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    %Show{}
    |> Show.changeset(%{
      date: DateTime.add(DateTime.utc_now(:second), 86_400, :second),
      venue_id: venue.id,
      notes: "Ignored Venue Show",
      ignored: true
    })
    |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    view
    |> element("#toggle-ignored-venue-shows")
    |> render_click()

    assert has_element?(view, "li", "Ignored Venue Show")
    assert has_element?(view, "#toggle-ignored-venue-shows", "Hide ignored shows")
  end

  test "can ignore a visible show from venue detail", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    show =
      %Show{}
      |> Show.changeset(%{
        date: DateTime.add(DateTime.utc_now(:second), 86_400, :second),
        venue_id: venue.id,
        notes: "Ignore From Venue"
      })
      |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    assert has_element?(view, "#toggle-ignore-venue-show-#{show.id}", "Ignore")

    view
    |> element("#toggle-ignore-venue-show-#{show.id}")
    |> render_click()

    assert render(view) =~ "Ignored: Ignore From Venue"
    refute has_element?(view, "li", "Ignore From Venue")
    assert Repo.get!(Show, show.id).ignored == true
  end

  test "can un-ignore a show from venue detail when ignored shows are visible", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    show =
      %Show{}
      |> Show.changeset(%{
        date: DateTime.add(DateTime.utc_now(:second), 86_400, :second),
        venue_id: venue.id,
        notes: "Unignore From Venue",
        ignored: true
      })
      |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}?show_ignored=true")

    assert has_element?(view, "#toggle-ignore-venue-show-#{show.id}", "Un-ignore")

    view
    |> element("#toggle-ignore-venue-show-#{show.id}")
    |> render_click()

    assert render(view) =~ "Un-ignored: Unignore From Venue"
    assert has_element?(view, "#toggle-ignore-venue-show-#{show.id}", "Ignore")
    assert Repo.get!(Show, show.id).ignored == false
  end

  test "shows collect source data button for Thalia Hall", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "Thalia Hall",
        website: "https://www.thaliahallchicago.com"
      })

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    assert has_element?(view, "#collect-thalia-schedule", "Collect Source Data")
  end

  test "does not show collect source data button for non-Thalia venues", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    refute has_element?(view, "#collect-thalia-schedule")
  end

  test "can add a venue source and view its raw payload", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    view
    |> element("#show-source-form")
    |> render_click()

    view
    |> form("#venue-source-form", %{
      "venue_source" => %{
        "source_key" => "thalia_hall_ticketmaster",
        "enabled" => "true",
        "payload_format" => "json",
        "raw_payload" => "{\"events\": []}"
      }
    })
    |> render_submit()

    assert render(view) =~ "Source added"
    assert has_element?(view, "#venue-sources-list", "thalia_hall_ticketmaster")
    assert has_element?(view, "#venue-sources-list", "{\"events\": []}")
  end

  test "can edit an existing venue source", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    source =
      %VenueSource{}
      |> VenueSource.changeset(%{
        venue_id: venue.id,
        source_key: "salt_shed_ticketmaster",
        payload_format: "json",
        raw_payload: "{\"events\": [1]}",
        enabled: true
      })
      |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    view
    |> element("#edit-source-#{source.id}")
    |> render_click()

    view
    |> form("#venue-source-form", %{
      "venue_source" => %{
        "source_key" => "salt_shed_ticketmaster",
        "enabled" => "false",
        "payload_format" => "html",
        "raw_payload" => "<div>updated</div>"
      }
    })
    |> render_submit()

    assert render(view) =~ "Source updated"
    assert has_element?(view, "#venue-sources-list", "<div>updated</div>")

    updated_source = Repo.get!(VenueSource, source.id)
    assert updated_source.enabled == false
    assert updated_source.payload_format == "html"
  end

  test "can delete an existing venue source", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    source =
      %VenueSource{}
      |> VenueSource.changeset(%{
        venue_id: venue.id,
        source_key: "salt_shed_ticketmaster",
        payload_format: "json",
        raw_payload: "{\"events\": [1]}",
        enabled: true
      })
      |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    view
    |> element("#delete-source-#{source.id}")
    |> render_click()

    assert render(view) =~ "Source deleted"
    refute has_element?(view, "#venue-source-#{source.id}")
    assert Repo.get(VenueSource, source.id) == nil
  end
end
