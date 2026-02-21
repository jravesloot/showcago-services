defmodule ShowcagoServicesWeb.Admin.VenueDetailLiveTest do
  use ShowcagoServicesWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Show
  alias ShowcagoServices.Schema.VenueSource
  alias ShowcagoServices.Venues

  test "renders venue schedule payload", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    %VenueSource{}
    |> VenueSource.changeset(%{
      venue_id: venue.id,
      source_type: "html_ld_json",
      raw_payload: "<div>Upcoming show</div>",
      payload_format: "html",
      fetched_at: DateTime.utc_now(:second),
      enabled: true
    })
    |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    assert has_element?(view, "#venue-schedule-payload")
    assert has_element?(view, "#venue-shows")
    assert render(view) =~ "Upcoming show"
    assert has_element?(view, ~s(a[href="/admin/venues/#{venue.id}/edit"]))
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

  test "shows collect schedule button for Thalia Hall", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "Thalia Hall",
        website: "https://www.thaliahallchicago.com"
      })

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    assert has_element?(view, "#collect-thalia-schedule", "Collect Schedule")
  end

  test "does not show collect schedule button for non-Thalia venues", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com"
      })

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    refute has_element?(view, "#collect-thalia-schedule")
  end
end
