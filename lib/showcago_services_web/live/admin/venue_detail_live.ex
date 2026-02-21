defmodule ShowcagoServicesWeb.Admin.VenueDetailLive do
  use ShowcagoServicesWeb, :live_view

  alias ShowcagoServices.Shows
  alias ShowcagoServices.Venues

  def mount(%{"id" => id}, _session, socket) do
    venue = Venues.get_venue!(id)

    {:ok,
     socket
     |> assign(:page_title, venue.name)
     |> assign(:venue, venue)
     |> assign(:show_ignored, false)
     |> assign(:shows, [])}
  end

  def handle_params(params, _uri, socket) do
    show_ignored = show_ignored?(params)

    {:noreply,
     socket
     |> assign(:show_ignored, show_ignored)
     |> assign(
       :shows,
       Venues.list_shows_for_venue(socket.assigns.venue.id, include_ignored: show_ignored)
     )}
  end

  def handle_event("collect-thalia-schedule", _params, socket) do
    case Venues.collect_thalia_hall_schedule_html() do
      {:ok, updated_venue, :updated} ->
        {:noreply,
         socket
         |> assign(:venue, updated_venue)
         |> put_flash(:info, "Collected Thalia Hall schedule")}

      {:ok, same_venue, :skipped} ->
        {:noreply,
         socket
         |> assign(:venue, same_venue)
         |> put_flash(:info, "Thalia Hall schedule recently collected; skipped")}

      {:error, :thalia_hall_not_found} ->
        {:noreply, put_flash(socket, :error, "Thalia Hall venue not found")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Unable to collect Thalia Hall schedule: #{inspect(reason)}")}
    end
  end

  def handle_event("toggle-ignore-show", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {show_id, ""} ->
        show = Shows.get_show!(show_id)

        if show.venue_id == socket.assigns.venue.id do
          next_ignored = !show.ignored

          case Shows.set_show_ignored(show, next_ignored) do
            {:ok, _updated_show} ->
              {:noreply,
               socket
               |> assign(
                 :shows,
                 Venues.list_shows_for_venue(
                   socket.assigns.venue.id,
                   include_ignored: socket.assigns.show_ignored
                 )
               )
               |> put_flash(:info, ignore_feedback_message(next_ignored, show))}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Unable to update show ignore status")}
          end
        else
          {:noreply, put_flash(socket, :error, "Show does not belong to this venue")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid show selection")}
    end
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
            <button
              :if={thalia_hall?(@venue)}
              id="collect-thalia-schedule"
              type="button"
              phx-click="collect-thalia-schedule"
              class="px-4 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-lg hover:bg-slate-50"
            >
              Collect Schedule
            </button>

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

        <div class="mb-6 rounded-lg border border-slate-200 bg-white shadow-sm">
          <div class="border-b border-slate-200 px-4 py-3 flex items-center justify-between gap-2">
            <h2 class="text-lg font-semibold text-slate-900">Shows</h2>
            <.link
              id="toggle-ignored-venue-shows"
              patch={
                if(@show_ignored,
                  do: ~p"/admin/venues/#{@venue.id}",
                  else: ~p"/admin/venues/#{@venue.id}?show_ignored=true"
                )
              }
              class="inline-flex items-center rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50"
            >
              {if(@show_ignored, do: "Hide ignored shows", else: "Show ignored shows")}
            </.link>
          </div>

          <div id="venue-shows" class="p-4">
            <div :if={@shows == []} class="text-sm text-slate-500">No shows for this venue yet.</div>

            <ul :if={@shows != []} class="space-y-3">
              <li
                :for={show <- @shows}
                id={"venue-show-#{show.id}"}
                class="rounded-lg border border-slate-200 bg-slate-50 px-3 py-2"
              >
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p class="text-sm font-semibold text-slate-900">
                      {show.notes || "Untitled event"}
                    </p>
                    <p class="text-xs text-slate-600">
                      {Calendar.strftime(show.date, "%A, %B %-d, %Y %I:%M %p")}
                    </p>
                    <p class="text-xs text-slate-700">Artists: {artist_names(show)}</p>
                  </div>

                  <button
                    id={"toggle-ignore-venue-show-#{show.id}"}
                    type="button"
                    phx-click="toggle-ignore-show"
                    phx-value-id={show.id}
                    class="inline-flex items-center rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50"
                  >
                    {if(show.ignored, do: "Un-ignore", else: "Ignore")}
                  </button>
                </div>
              </li>
            </ul>
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

  defp thalia_hall?(venue), do: venue.name == "Thalia Hall"

  defp show_ignored?(%{"show_ignored" => value}) when value in ["true", "1"], do: true
  defp show_ignored?(_params), do: false

  defp artist_names(show) do
    show.artists
    |> Enum.map(& &1.name)
    |> Enum.join(", ")
    |> case do
      "" -> "Unmatched"
      names -> names
    end
  end

  defp ignore_feedback_message(true, show), do: "Ignored: #{show_title(show)}"
  defp ignore_feedback_message(false, show), do: "Un-ignored: #{show_title(show)}"

  defp show_title(show), do: show.notes || "Untitled event"
end
