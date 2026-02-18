defmodule ShowcagoServicesWeb.Admin.ShowLiveTest do
  use ShowcagoServicesWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Artist
  alias ShowcagoServices.Schema.Show
  alias ShowcagoServices.Schema.Venue

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
end
