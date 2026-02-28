defmodule ShowcagoServicesWeb.Admin.ShowLiveTest do
  use ShowcagoServicesWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Artist
  alias ShowcagoServices.Schema.Show
  alias ShowcagoServices.Schema.Venue

  setup :register_and_log_in_admin_user

  test "shows upcoming events grouped by date", %{conn: conn} do
    venue =
      %Venue{}
      |> Venue.changeset(%{name: "The Salt Shed"})
      |> Repo.insert!()

    artist =
      %Artist{}
      |> Artist.changeset(%{name: "Boris"})
      |> Repo.insert!()

    show =
      %Show{}
      |> Show.changeset(%{
        date: DateTime.add(DateTime.utc_now(:second), 86_400, :second),
        venue_id: venue.id,
        notes: "Boris Live",
        ticket_url: "https://example.com/tickets"
      })
      |> Repo.insert!()

    now = DateTime.utc_now(:second)

    Repo.insert_all("show_artists", [
      %{show_id: show.id, artist_id: artist.id, inserted_at: now, updated_at: now}
    ])

    {:ok, view, _html} = live(conn, ~p"/admin/shows")

    assert has_element?(view, "h1", "Upcoming Shows")
    assert render(view) =~ "Boris Live"
    assert render(view) =~ "The Salt Shed"
    assert render(view) =~ "Artists: Boris"
    assert has_element?(view, ~s(a[href="https://example.com/tickets"]))
  end

  test "does not show past shows", %{conn: conn} do
    venue =
      %Venue{}
      |> Venue.changeset(%{name: "Metro"})
      |> Repo.insert!()

    %Show{}
    |> Show.changeset(%{
      date: DateTime.add(DateTime.utc_now(:second), -86_400, :second),
      venue_id: venue.id,
      notes: "Past Show"
    })
    |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/shows")

    refute render(view) =~ "Past Show"
  end

  test "hides ignored shows by default", %{conn: conn} do
    venue =
      %Venue{}
      |> Venue.changeset(%{name: "Metro"})
      |> Repo.insert!()

    %Show{}
    |> Show.changeset(%{
      date: DateTime.add(DateTime.utc_now(:second), 86_400, :second),
      venue_id: venue.id,
      notes: "Ignored Show",
      ignored: true
    })
    |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/shows")

    refute has_element?(view, "li", "Ignored Show")
    refute has_element?(view, "span", "Ignored")
    assert has_element?(view, "#toggle-ignored-shows", "Show ignored shows")
  end

  test "shows ignored shows when toggled", %{conn: conn} do
    venue =
      %Venue{}
      |> Venue.changeset(%{name: "Metro"})
      |> Repo.insert!()

    %Show{}
    |> Show.changeset(%{
      date: DateTime.add(DateTime.utc_now(:second), 86_400, :second),
      venue_id: venue.id,
      notes: "Ignored Show",
      ignored: true
    })
    |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/shows")

    assert has_element?(view, "#toggle-ignored-shows", "Show ignored shows")

    view
    |> element("#toggle-ignored-shows")
    |> render_click()

    assert has_element?(view, "li", "Ignored Show")
    assert has_element?(view, "span", "Ignored")
    assert has_element?(view, "#toggle-ignored-shows", "Hide ignored shows")
  end

  test "can ignore a visible show from the row action", %{conn: conn} do
    venue =
      %Venue{}
      |> Venue.changeset(%{name: "Metro"})
      |> Repo.insert!()

    show =
      %Show{}
      |> Show.changeset(%{
        date: DateTime.add(DateTime.utc_now(:second), 86_400, :second),
        venue_id: venue.id,
        notes: "Ignore Me",
        ignored: false
      })
      |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/shows")

    assert has_element?(view, "li", "Ignore Me")
    assert has_element?(view, "#toggle-ignore-show-#{show.id}", "Ignore")

    view
    |> element("#toggle-ignore-show-#{show.id}")
    |> render_click()

    assert render(view) =~ "Ignored: Ignore Me"
    refute has_element?(view, "li", "Ignore Me")
    assert Repo.get!(Show, show.id).ignored == true
  end

  test "can un-ignore a show from the row action when ignored shows are visible", %{conn: conn} do
    venue =
      %Venue{}
      |> Venue.changeset(%{name: "Metro"})
      |> Repo.insert!()

    show =
      %Show{}
      |> Show.changeset(%{
        date: DateTime.add(DateTime.utc_now(:second), 86_400, :second),
        venue_id: venue.id,
        notes: "Bring Me Back",
        ignored: true
      })
      |> Repo.insert!()

    {:ok, view, _html} = live(conn, ~p"/admin/shows?show_ignored=true")

    assert has_element?(view, "li", "Bring Me Back")
    assert has_element?(view, "#toggle-ignore-show-#{show.id}", "Un-ignore")

    view
    |> element("#toggle-ignore-show-#{show.id}")
    |> render_click()

    assert render(view) =~ "Un-ignored: Bring Me Back"
    assert has_element?(view, "li", "Bring Me Back")
    assert has_element?(view, "#toggle-ignore-show-#{show.id}", "Ignore")
    assert Repo.get!(Show, show.id).ignored == false
  end
end
