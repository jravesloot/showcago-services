defmodule ShowcagoServicesWeb.Admin.ShowLive do
  @moduledoc false
  use ShowcagoServicesWeb, :live_view

  alias ShowcagoServices.Shows

  @chicago_time_zone "America/Chicago"

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Shows")
     |> assign(:show_ignored, false)
     |> assign(:grouped_shows, [])}
  end

  def handle_params(params, _uri, socket) do
    show_ignored = show_ignored?(params)

    {:noreply,
     socket
     |> assign(:show_ignored, show_ignored)
     |> assign(:grouped_shows, list_grouped_shows(show_ignored))}
  end

  def handle_event("toggle-ignore-show", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {show_id, ""} ->
        show = Shows.get_show!(show_id)
        next_ignored = !show.ignored

        case Shows.set_show_ignored(show, next_ignored) do
          {:ok, _updated_show} ->
            {:noreply,
             socket
             |> assign(:grouped_shows, list_grouped_shows(socket.assigns.show_ignored))
             |> put_flash(:info, ignore_feedback_message(next_ignored, show))}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Unable to update show ignore status")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid show selection")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]} full_width={true}>
      <ShowcagoServicesWeb.AdminComponents.admin_layout active_page={:shows}>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Upcoming Shows</h1>
          <p class="mt-2 text-sm text-gray-600">Events grouped by date across all venues</p>
          <div class="mt-4">
            <.link
              id="toggle-ignored-shows"
              patch={
                if(@show_ignored, do: ~p"/admin/shows", else: ~p"/admin/shows?show_ignored=true")
              }
              class="inline-flex items-center rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-50"
            >
              {if(@show_ignored, do: "Hide ignored shows", else: "Show ignored shows")}
            </.link>
          </div>
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
            </div>

            <div class="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
              <ul class="divide-y divide-slate-200">
                <li :for={show <- shows} class="px-5 py-4">
                  <div class="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <div class="flex items-center gap-2">
                        <p class="text-base font-semibold text-slate-900">
                          {show.notes || "Untitled event"}
                        </p>
                        <span
                          :if={show.ignored}
                          class="inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600"
                        >
                          Ignored
                        </span>
                      </div>
                      <p class="mt-1 text-sm text-slate-600">
                        {show_time(show)} • {show.venue && show.venue.name}
                      </p>
                      <p class="mt-1 text-sm text-slate-700">
                        Artists: {artist_names(show)}
                      </p>
                    </div>

                    <div class="flex items-center gap-2">
                      <button
                        id={"toggle-ignore-show-#{show.id}"}
                        type="button"
                        phx-click="toggle-ignore-show"
                        phx-value-id={show.id}
                        class="inline-flex items-center rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-50"
                      >
                        {if(show.ignored, do: "Un-ignore", else: "Ignore")}
                      </button>

                      <a
                        :if={show.ticket_url}
                        href={show.ticket_url}
                        target="_blank"
                        class="inline-flex items-center rounded-lg border border-blue-200 bg-blue-50 px-3 py-2 text-sm font-medium text-blue-700 hover:bg-blue-100"
                      >
                        Tickets
                      </a>
                    </div>
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
    |> Enum.map_join(", ", & &1.name)
    |> case do
      "" -> "Unmatched"
      names -> names
    end
  end

  defp show_time(show) do
    show.date
    |> chicago_datetime()
    |> Calendar.strftime("%I:%M %p")
    |> Kernel.<>(" CT")
  end

  defp chicago_datetime(%DateTime{} = datetime) do
    case DateTime.shift_zone(datetime, @chicago_time_zone) do
      {:ok, shifted_datetime} -> shifted_datetime
      _ -> datetime
    end
  end

  defp show_ignored?(%{"show_ignored" => value}) when value in ["true", "1"], do: true
  defp show_ignored?(_params), do: false

  defp list_grouped_shows(show_ignored) do
    Shows.list_upcoming_shows_grouped_by_date(include_ignored: show_ignored)
  end

  defp ignore_feedback_message(true, show), do: "Ignored: #{show_title(show)}"
  defp ignore_feedback_message(false, show), do: "Un-ignored: #{show_title(show)}"

  defp show_title(show), do: show.notes || "Untitled event"
end
