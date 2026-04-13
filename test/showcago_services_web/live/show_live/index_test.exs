defmodule ShowcagoServicesWeb.ShowLive.IndexTest do
  use ShowcagoServicesWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Artist
  alias ShowcagoServices.Schema.Show
  alias ShowcagoServices.Schema.Venue

  defp create_venue(attrs \\ %{}) do
    %Venue{}
    |> Venue.changeset(Map.merge(%{name: "The Salt Shed"}, attrs))
    |> Repo.insert!()
  end

  defp create_show(venue, attrs) do
    %Show{}
    |> Show.changeset(
      Map.merge(
        %{
          date: DateTime.add(DateTime.utc_now(:second), 86_400, :second),
          venue_id: venue.id
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp create_artist(name) do
    %Artist{}
    |> Artist.changeset(%{name: name})
    |> Repo.insert!()
  end

  defp link_artist(show, artist) do
    now = DateTime.utc_now(:second)

    Repo.insert_all("show_artists", [
      %{show_id: show.id, artist_id: artist.id, inserted_at: now, updated_at: now}
    ])
  end

  describe "unauthenticated access" do
    test "renders the shows page without login", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/shows")

      assert html =~ "Upcoming Shows"
      assert html =~ "Live music events across Chicago venues"
    end

    test "shows empty state when no upcoming shows", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/shows")

      assert has_element?(view, "#no-shows")
      assert has_element?(view, "p", "No upcoming shows")
    end
  end

  describe "authenticated access" do
    setup :register_and_log_in_user

    test "renders the shows page when logged in", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/shows")

      assert html =~ "Upcoming Shows"
    end
  end

  describe "show listing" do
    test "displays upcoming shows with venue and artist info", %{conn: conn} do
      venue = create_venue(%{name: "Metro"})
      artist = create_artist("Boris")
      show = create_show(venue, %{notes: "Boris Live", ticket_url: "https://example.com/tickets"})
      link_artist(show, artist)

      {:ok, view, _html} = live(conn, ~p"/shows")

      assert render(view) =~ "Boris Live"
      assert render(view) =~ "Metro"
      assert render(view) =~ "Boris"
      assert has_element?(view, ~s(a[href="https://example.com/tickets"]), "Tickets")
    end

    test "does not show past shows", %{conn: conn} do
      venue = create_venue()

      create_show(venue, %{
        date: DateTime.add(DateTime.utc_now(:second), -86_400, :second),
        notes: "Past Show"
      })

      {:ok, view, _html} = live(conn, ~p"/shows")

      refute render(view) =~ "Past Show"
      assert has_element?(view, "#no-shows")
    end

    test "does not show ignored shows", %{conn: conn} do
      venue = create_venue()
      create_show(venue, %{notes: "Ignored Show", ignored: true})

      {:ok, view, _html} = live(conn, ~p"/shows")

      refute render(view) =~ "Ignored Show"
    end

    test "groups shows by date", %{conn: conn} do
      venue = create_venue()

      create_show(venue, %{
        date: DateTime.add(DateTime.utc_now(:second), 86_400, :second),
        notes: "Tomorrow Show"
      })

      create_show(venue, %{
        date: DateTime.add(DateTime.utc_now(:second), 172_800, :second),
        notes: "Day After Show"
      })

      {:ok, view, html} = live(conn, ~p"/shows")

      assert html =~ "Tomorrow Show"
      assert html =~ "Day After Show"

      tomorrow = Date.add(Date.utc_today(), 1)
      day_after = Date.add(Date.utc_today(), 2)
      assert has_element?(view, "#date-#{tomorrow}")
      assert has_element?(view, "#date-#{day_after}")
    end

    test "displays price range when present", %{conn: conn} do
      venue = create_venue()
      create_show(venue, %{notes: "Priced Show", price_min: Decimal.new("25"), price_max: Decimal.new("50")})

      {:ok, _view, html} = live(conn, ~p"/shows")

      assert html =~ "$25"
      assert html =~ "$50"
    end

    test "displays single price when min equals max", %{conn: conn} do
      venue = create_venue()
      create_show(venue, %{notes: "Fixed Price", price_min: Decimal.new("30"), price_max: Decimal.new("30")})

      {:ok, _view, html} = live(conn, ~p"/shows")

      assert html =~ "$30"
    end

    test "hides ticket link when no URL", %{conn: conn} do
      venue = create_venue()
      create_show(venue, %{notes: "No Tickets", ticket_url: nil})

      {:ok, view, _html} = live(conn, ~p"/shows")

      refute has_element?(view, ~s(a[target="_blank"]), "Tickets")
    end

    test "renders multiple artists for a show", %{conn: conn} do
      venue = create_venue()
      show = create_show(venue, %{notes: "Double Bill"})

      artist1 = create_artist("Band One")
      artist2 = create_artist("Band Two")
      link_artist(show, artist1)
      link_artist(show, artist2)

      {:ok, _view, html} = live(conn, ~p"/shows")

      assert html =~ "Band One"
      assert html =~ "Band Two"
    end
  end
end
