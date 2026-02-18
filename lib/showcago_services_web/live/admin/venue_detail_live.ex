defmodule ShowcagoServicesWeb.Admin.VenueDetailLive do
  use ShowcagoServicesWeb, :live_view

  alias ShowcagoServices.Venues

  def mount(%{"id" => id}, _session, socket) do
    venue = Venues.get_venue!(id)

    {:ok,
     socket
     |> assign(:page_title, venue.name)
     |> assign(:venue, venue)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]} full_width={true}>
      <ShowcagoServicesWeb.AdminComponents.admin_layout active_page={:venues}>
        <div class="mb-6 flex items-center justify-between gap-4">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">{@venue.name}</h1>
            <p class="mt-2 text-sm text-gray-600">Venue detail and collected schedule HTML</p>
          </div>

          <div class="flex items-center gap-2">
            <.link
              navigate={~p"/admin/venues/#{@venue.id}/edit"}
              class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700"
            >
              Edit Venue
            </.link>
            <.link
              navigate={~p"/admin/venues"}
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Back to Venues
            </.link>
          </div>
        </div>

        <div class="mb-6 grid grid-cols-1 gap-4 lg:grid-cols-2">
          <div class="rounded-lg border border-slate-200 bg-white p-4">
            <h2 class="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
              Metadata
            </h2>
            <dl class="space-y-2 text-sm text-slate-700">
              <div>
                <dt class="font-medium text-slate-900">Website</dt>
                <dd>
                  <a
                    :if={@venue.website}
                    href={@venue.website}
                    target="_blank"
                    class="text-blue-700 hover:underline"
                  >
                    {@venue.website}
                  </a>
                  <span :if={!@venue.website} class="text-slate-400">Not set</span>
                </dd>
              </div>
              <div>
                <dt class="font-medium text-slate-900">Data Last Collected</dt>
                <dd>
                  <span :if={@venue.data_last_collected}>{@venue.data_last_collected}</span>
                  <span :if={!@venue.data_last_collected} class="text-slate-400">Never</span>
                </dd>
              </div>
            </dl>
          </div>

          <div class="rounded-lg border border-slate-200 bg-white p-4">
            <h2 class="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
              Location
            </h2>
            <p class="text-sm text-slate-700">
              {@venue.address} {@venue.city} {@venue.state} {@venue.zip_code}
            </p>
          </div>
        </div>

        <div class="rounded-lg border border-slate-200 bg-white shadow-sm">
          <div class="border-b border-slate-200 px-4 py-3">
            <h2 class="text-lg font-semibold text-slate-900">Schedule HTML</h2>
          </div>

          <div class="p-4">
            <pre
              id="venue-schedule-html"
              class="max-h-[60vh] overflow-auto whitespace-pre-wrap rounded-lg bg-slate-950 p-4 text-xs text-slate-100"
            ><%= @venue.schedule_html || "No schedule HTML collected yet." %></pre>
          </div>
        </div>
      </ShowcagoServicesWeb.AdminComponents.admin_layout>
    </Layouts.app>
    """
  end
end
