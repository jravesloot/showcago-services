defmodule ShowcagoServicesWeb.Admin.VenueDetailLiveTest do
  use ShowcagoServicesWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ShowcagoServices.Venues

  test "renders venue schedule html", %{conn: conn} do
    {:ok, venue} =
      Venues.create_venue(%{
        name: "The Salt Shed",
        website: "https://www.saltshedchicago.com",
        schedule_html: "<div>Upcoming show</div>"
      })

    {:ok, view, _html} = live(conn, ~p"/admin/venues/#{venue.id}")

    assert has_element?(view, "#venue-schedule-html")
    assert render(view) =~ "Upcoming show"
    assert has_element?(view, ~s(a[href="/admin/venues/#{venue.id}/edit"]))
  end
end
