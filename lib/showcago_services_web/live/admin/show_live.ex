defmodule ShowcagoServicesWeb.Admin.ShowLive do
  use ShowcagoServicesWeb, :live_view

  alias ShowcagoServices.Shows

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Shows")
     |> assign(:grouped_shows, Shows.list_upcoming_shows_grouped_by_date())}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]} full_width={true}>
      <ShowcagoServicesWeb.AdminComponents.admin_layout active_page={:shows}>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Upcoming Shows</h1>
          <p class="mt-2 text-sm text-gray-600">Events grouped by date across all venues</p>
        </div>

        <div
          :if={@grouped_shows == []}
          class="rounded-lg border border-slate-200 bg-white px-6 py-12 text-center text-gray-500"
        >
          <p class="text-lg">No upcoming shows found</p>
          <p class="mt-2 text-sm">Once show data is parsed, results will appear here.</p>
        </div>

        <div :if={@grouped_shows != []} class="space-y-8">
          <section :for={{date, shows} <- @grouped_shows} id={"shows-#{date}"}>
            <div class="mb-3 flex items-center gap-3">
              <h2 class="text-xl font-semibold text-slate-900">
                {Calendar.strftime(date, "%A, %B %-d, %Y")}
              </h2>
              <span class="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-600">
                {length(shows)} show(s)
              </span>
            </div>

            <div class="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
              <ul class="divide-y divide-slate-200">
                <li :for={show <- shows} class="px-5 py-4">
                  <div class="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <p class="text-base font-semibold text-slate-900">
                        {show.notes || "Untitled event"}
                      </p>
                      <p class="mt-1 text-sm text-slate-600">
                        {show_time(show)} • {show.venue && show.venue.name}
                      </p>
                      <p class="mt-1 text-sm text-slate-700">
                        Artists: {artist_names(show)}
                      </p>
                    </div>

                    <a
                      :if={show.ticket_url}
                      href={show.ticket_url}
                      target="_blank"
                      class="inline-flex items-center rounded-lg border border-blue-200 bg-blue-50 px-3 py-2 text-sm font-medium text-blue-700 hover:bg-blue-100"
                    >
                      Tickets
                    </a>
                  </div>
                </li>
              </ul>
            </div>
          </section>
        </div>
      </ShowcagoServicesWeb.AdminComponents.admin_layout>
    </Layouts.app>
    """
  end

  defp artist_names(show) do
    show.artists
    |> Enum.map(& &1.name)
    |> Enum.join(", ")
    |> case do
      "" -> "Unmatched"
      names -> names
    end
  end

  defp show_time(show) do
    Calendar.strftime(show.date, "%I:%M %p")
  end
end
