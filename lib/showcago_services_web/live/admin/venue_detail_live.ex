defmodule ShowcagoServicesWeb.Admin.VenueDetailLive do
  use ShowcagoServicesWeb, :live_view

  alias ShowcagoServices.Schema.VenueSource
  alias ShowcagoServices.Shows
  alias ShowcagoServices.Venues

  @chicago_time_zone "America/Chicago"

  def mount(%{"id" => id}, _session, socket) do
    venue = Venues.get_venue!(id)

    {:ok,
     socket
     |> assign(:page_title, venue.name)
     |> assign(:venue, venue)
     |> assign(:last_collected_at, Venues.latest_source_fetched_at_for_venue(venue))
     |> assign(:venue_sources, Venues.list_venue_sources(venue))
     |> assign(:editing_source_id, nil)
     |> assign(:show_source_form, false)
     |> assign(:source_form, to_form(Venues.change_venue_source(%VenueSource{})))
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
    case Venues.collect_schedule_payload_for_source("thalia_hall_ticketmaster") do
      {:ok, updated_venue, :updated} ->
        {:noreply,
         socket
         |> assign(:venue, updated_venue)
         |> assign(:last_collected_at, Venues.latest_source_fetched_at_for_venue(updated_venue))
         |> put_flash(:info, "Collected Thalia Hall source data")}

      {:ok, same_venue, :skipped} ->
        {:noreply,
         socket
         |> assign(:venue, same_venue)
         |> assign(:last_collected_at, Venues.latest_source_fetched_at_for_venue(same_venue))
         |> put_flash(:info, "Thalia Hall source data recently collected; skipped")}

      {:error, :thalia_hall_not_found} ->
        {:noreply, put_flash(socket, :error, "Thalia Hall venue not found")}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Unable to collect Thalia Hall source data: #{inspect(reason)}"
         )}
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

  def handle_event("validate-source", %{"venue_source" => source_params}, socket) do
    changeset =
      socket
      |> source_changeset_for_editing(source_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :source_form, to_form(changeset))}
  end

  def handle_event("save-source", %{"venue_source" => source_params}, socket) do
    case socket.assigns.editing_source_id do
      nil ->
        case Venues.create_venue_source(socket.assigns.venue, source_params) do
          {:ok, _source} ->
            {:noreply,
             socket
             |> refresh_source_assigns()
             |> reset_source_form()
             |> put_flash(:info, "Source added")}

          {:error, changeset} ->
            {:noreply, assign(socket, :source_form, to_form(changeset))}
        end

      editing_source_id ->
        case Venues.get_venue_source(socket.assigns.venue, editing_source_id) do
          nil ->
            {:noreply,
             socket
             |> reset_source_form()
             |> put_flash(:error, "Source not found")}

          source ->
            case Venues.update_venue_source(source, source_params) do
              {:ok, _updated_source} ->
                {:noreply,
                 socket
                 |> refresh_source_assigns()
                 |> reset_source_form()
                 |> put_flash(:info, "Source updated")}

              {:error, changeset} ->
                {:noreply, assign(socket, :source_form, to_form(changeset))}
            end
        end
    end
  end

  def handle_event("edit-source", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {source_id, ""} ->
        case Venues.get_venue_source(socket.assigns.venue, source_id) do
          nil ->
            {:noreply, put_flash(socket, :error, "Source not found")}

          source ->
            {:noreply,
             socket
             |> assign(:editing_source_id, source.id)
             |> assign(:show_source_form, true)
             |> assign(:source_form, to_form(Venues.change_venue_source(source)))}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid source selection")}
    end
  end

  def handle_event("cancel-source-edit", _params, socket) do
    {:noreply, reset_source_form(socket)}
  end

  def handle_event("show-source-form", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_source_id, nil)
     |> assign(:show_source_form, true)
     |> assign(:source_form, to_form(Venues.change_venue_source(%VenueSource{})))}
  end

  def handle_event("delete-source", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {source_id, ""} ->
        case Venues.get_venue_source(socket.assigns.venue, source_id) do
          nil ->
            {:noreply, put_flash(socket, :error, "Source not found")}

          source ->
            case Venues.delete_venue_source(source) do
              {:ok, _deleted_source} ->
                {:noreply,
                 socket
                 |> refresh_source_assigns()
                 |> reset_source_form()
                 |> put_flash(:info, "Source deleted")}

              {:error, _changeset} ->
                {:noreply, put_flash(socket, :error, "Unable to delete source")}
            end
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid source selection")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]} full_width={true}>
      <ShowcagoServicesWeb.AdminComponents.admin_layout active_page={:venues}>
        <div class="mb-6 flex items-center justify-between gap-4">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">{@venue.name}</h1>
            <p class="mt-2 text-sm text-gray-600">Venue detail, source management, and shows</p>
          </div>

          <div class="flex items-center gap-2">
            <button
              :if={thalia_hall?(@venue)}
              id="collect-thalia-schedule"
              type="button"
              phx-click="collect-thalia-schedule"
              class="px-4 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-lg hover:bg-slate-50"
            >
              Collect Source Data
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
                <dt class="font-medium text-slate-900">Source Last Collected</dt>
                <dd>
                  <span :if={@last_collected_at}>
                    {format_chicago_datetime(@last_collected_at)}
                  </span>
                  <span :if={!@last_collected_at} class="text-slate-400">Never</span>
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
                      {format_chicago_datetime(show.date)}
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

        <div class="mb-6 rounded-lg border border-slate-200 bg-white shadow-sm">
          <div class="border-b border-slate-200 px-4 py-3">
            <h2 class="text-lg font-semibold text-slate-900">Sources</h2>
          </div>

          <div class="p-4">
            <div id="venue-sources-list" class="mb-4">
              <div :if={@venue_sources == []} class="text-sm text-slate-500">
                No sources configured yet.
              </div>

              <ul :if={@venue_sources != []} class="space-y-3">
                <li
                  :for={source <- @venue_sources}
                  id={"venue-source-#{source.id}"}
                  class="rounded-lg border border-slate-200 bg-slate-50 p-3"
                >
                  <div class="mb-2 flex items-start justify-between gap-3">
                    <div>
                      <p class="text-sm font-semibold text-slate-900">{source.source_key}</p>
                      <p class="text-xs text-slate-600">
                        Enabled: {if(source.enabled, do: "Yes", else: "No")}
                      </p>
                      <p class="text-xs text-slate-600">
                        Last collected: {format_source_fetched_at(source.fetched_at)}
                      </p>
                    </div>

                    <div class="flex items-center gap-2">
                      <button
                        id={"edit-source-#{source.id}"}
                        type="button"
                        phx-click="edit-source"
                        phx-value-id={source.id}
                        class="inline-flex items-center rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50"
                      >
                        Edit
                      </button>

                      <button
                        id={"delete-source-#{source.id}"}
                        type="button"
                        phx-click="delete-source"
                        phx-value-id={source.id}
                        class="inline-flex items-center rounded-lg border border-red-300 bg-white px-3 py-1.5 text-xs font-medium text-red-700 transition hover:bg-red-50"
                      >
                        Delete
                      </button>
                    </div>
                  </div>

                  <pre
                    id={"source-raw-payload-#{source.id}"}
                    class="max-h-48 overflow-auto whitespace-pre-wrap rounded-lg bg-slate-950 p-3 text-xs text-slate-100"
                  >{source.raw_payload || "No source payload yet."}</pre>
                </li>
              </ul>
            </div>

            <div class="flex items-center gap-2">
              <button
                :if={!@editing_source_id && !@show_source_form}
                id="show-source-form"
                type="button"
                phx-click="show-source-form"
                class="inline-flex items-center rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50"
              >
                New Source
              </button>
            </div>

            <.form
              :if={@show_source_form || @editing_source_id}
              id="venue-source-form"
              for={@source_form}
              phx-change="validate-source"
              phx-submit="save-source"
              class="mt-3 space-y-3"
            >
              <.input field={@source_form[:source_key]} label="Source key" type="text" />
              <.input field={@source_form[:enabled]} label="Enabled" type="checkbox" />
              <.input field={@source_form[:payload_format]} label="Payload format" type="text" />
              <.input field={@source_form[:raw_payload]} label="Raw payload" type="textarea" rows="6" />

              <div class="flex items-center gap-2">
                <button
                  id="save-venue-source"
                  type="submit"
                  class="inline-flex items-center rounded-lg bg-blue-600 px-3 py-1.5 text-xs font-medium text-white transition hover:bg-blue-700"
                >
                  {if(@editing_source_id, do: "Update Source", else: "Add Source")}
                </button>

                <button
                  :if={!@editing_source_id && @show_source_form}
                  id="cancel-new-source"
                  type="button"
                  phx-click="cancel-source-edit"
                  class="inline-flex items-center rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50"
                >
                  Cancel
                </button>

                <button
                  :if={@editing_source_id}
                  id="cancel-venue-source-edit"
                  type="button"
                  phx-click="cancel-source-edit"
                  class="inline-flex items-center rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50"
                >
                  Cancel
                </button>
              </div>
            </.form>
          </div>
        </div>
      </ShowcagoServicesWeb.AdminComponents.admin_layout>
    </Layouts.app>
    """
  end

  defp thalia_hall?(venue), do: venue.name == "Thalia Hall"

  defp show_ignored?(%{"show_ignored" => value}) when value in ["true", "1"], do: true
  defp show_ignored?(_params), do: false

  defp source_changeset_for_editing(socket, source_params) do
    case socket.assigns.editing_source_id do
      nil ->
        Venues.change_venue_source(%VenueSource{}, source_params)

      editing_source_id ->
        case Venues.get_venue_source(socket.assigns.venue, editing_source_id) do
          nil -> Venues.change_venue_source(%VenueSource{}, source_params)
          source -> Venues.change_venue_source(source, source_params)
        end
    end
  end

  defp refresh_source_assigns(socket) do
    venue = socket.assigns.venue

    socket
    |> assign(:venue_sources, Venues.list_venue_sources(venue))
    |> assign(:last_collected_at, Venues.latest_source_fetched_at_for_venue(venue))
  end

  defp reset_source_form(socket) do
    socket
    |> assign(:editing_source_id, nil)
    |> assign(:show_source_form, false)
    |> assign(:source_form, to_form(Venues.change_venue_source(%VenueSource{})))
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

  defp ignore_feedback_message(true, show), do: "Ignored: #{show_title(show)}"
  defp ignore_feedback_message(false, show), do: "Un-ignored: #{show_title(show)}"

  defp show_title(show), do: show.notes || "Untitled event"

  defp format_source_fetched_at(nil), do: "Not collected"
  defp format_source_fetched_at(%DateTime{} = datetime), do: format_chicago_datetime(datetime)

  defp format_chicago_datetime(%DateTime{} = datetime) do
    datetime
    |> chicago_datetime()
    |> Calendar.strftime("%A, %B %-d, %Y %I:%M %p")
    |> Kernel.<>(" CT")
  end

  defp chicago_datetime(%DateTime{} = datetime) do
    case DateTime.shift_zone(datetime, @chicago_time_zone) do
      {:ok, shifted_datetime} -> shifted_datetime
      _ -> datetime
    end
  end
end
