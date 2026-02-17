defmodule ShowcagoServicesWeb.Admin.VenueLive do
  use ShowcagoServicesWeb, :live_view

  alias ShowcagoServices.Venues
  alias ShowcagoServices.Schema.Venue

  @per_page 50

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search, "")
     |> assign(:editing_venue_id, nil)
     |> assign(:form, nil)
     |> assign(:page, 1)
     |> assign(:per_page, @per_page)
     |> load_venues()}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Venues")
    |> assign(:editing_venue_id, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Venue")
    |> assign(:form, to_form(Venues.venue_changeset(%Venue{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    venue = Venues.get_venue!(id)

    socket
    |> assign(:page_title, "Edit Venue")
    |> assign(:editing_venue_id, String.to_integer(id))
    |> assign(:form, to_form(Venues.venue_changeset(venue)))
  end

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:search, search)
     |> assign(:page, 1)
     |> load_venues()}
  end

  def handle_event("next_page", _params, socket) do
    {:noreply,
     socket
     |> assign(:page, socket.assigns.page + 1)
     |> load_venues()}
  end

  def handle_event("prev_page", _params, socket) do
    {:noreply,
     socket
     |> assign(:page, max(1, socket.assigns.page - 1))
     |> load_venues()}
  end

  def handle_event("validate", %{"venue" => venue_params}, socket) do
    changeset =
      if socket.assigns.editing_venue_id do
        venue = Venues.get_venue!(socket.assigns.editing_venue_id)
        Venues.venue_changeset(venue, venue_params)
      else
        Venues.venue_changeset(%Venue{}, venue_params)
      end

    {:noreply, assign(socket, :form, to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("save", %{"venue" => venue_params}, socket) do
    save_venue(socket, socket.assigns.live_action, venue_params)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    venue = Venues.get_venue!(id)

    case Venues.delete_venue(venue) do
      {:ok, _venue} ->
        {:noreply,
         socket
         |> put_flash(:info, "Venue deleted successfully")
         |> load_venues()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete venue")}
    end
  end

  defp save_venue(socket, :new, venue_params) do
    case Venues.create_venue(venue_params) do
      {:ok, _venue} ->
        {:noreply,
         socket
         |> put_flash(:info, "Venue created successfully")
         |> push_navigate(to: ~p"/admin/venues")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_venue(socket, :edit, venue_params) do
    venue = Venues.get_venue!(socket.assigns.editing_venue_id)

    case Venues.update_venue(venue, venue_params) do
      {:ok, _venue} ->
        {:noreply,
         socket
         |> put_flash(:info, "Venue updated successfully")
         |> push_navigate(to: ~p"/admin/venues")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp load_venues(socket) do
    offset = (socket.assigns.page - 1) * socket.assigns.per_page

    venues =
      Venues.list_venues(
        search: socket.assigns.search,
        limit: socket.assigns.per_page,
        offset: offset
      )

    total_count = Venues.count_venues(search: socket.assigns.search)
    total_pages = ceil(total_count / socket.assigns.per_page)

    socket
    |> assign(:venues, venues)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  defp format_location(venue) do
    parts =
      [
        if(venue.city, do: venue.city, else: nil),
        if(venue.state, do: venue.state, else: nil),
        if(venue.zip_code, do: venue.zip_code, else: nil)
      ]
      |> Enum.reject(&is_nil/1)

    cond do
      length(parts) == 0 -> ""
      length(parts) == 1 -> Enum.at(parts, 0)
      true -> Enum.join(parts, ", ")
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]} full_width={true}>
      <ShowcagoServicesWeb.AdminComponents.admin_layout active_page={:venues}>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Venues</h1>
          <p class="mt-2 text-sm text-gray-600">Manage venues for upcoming shows</p>
        </div>

        <%= if @live_action in [:new, :edit] do %>
          <div class="mb-8 bg-white shadow-sm rounded-lg p-6">
            <div class="mb-6">
              <h2 class="text-2xl font-bold text-gray-900">
                {@page_title}
              </h2>
            </div>

            <.form for={@form} id="venue-form" phx-change="validate" phx-submit="save">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="md:col-span-2">
                  <.input field={@form[:name]} type="text" label="Name" required />
                </div>

                <div class="md:col-span-2">
                  <.input field={@form[:address]} type="text" label="Address" />
                </div>

                <div>
                  <.input field={@form[:city]} type="text" label="City" />
                </div>

                <div>
                  <.input field={@form[:state]} type="text" label="State" />
                </div>

                <div>
                  <.input field={@form[:zip_code]} type="text" label="Zip Code" />
                </div>

                <div>
                  <.input field={@form[:website]} type="text" label="Website" />
                </div>
              </div>

              <div class="mt-6 flex gap-3">
                <button
                  type="submit"
                  class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700"
                >
                  Save
                </button>
                <.link
                  navigate={~p"/admin/venues"}
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Cancel
                </.link>
              </div>
            </.form>
          </div>
        <% end %>

        <div class="mb-6 flex gap-4 items-center">
          <form phx-change="search" class="flex-1">
            <input
              type="text"
              name="search"
              value={@search}
              placeholder="Search venues by name, city, or address..."
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </form>

          <.link
            navigate={~p"/admin/venues/new"}
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors whitespace-nowrap"
          >
            Add Venue
          </.link>
        </div>

        <div class="bg-white shadow-sm rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Name
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Location
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr :for={venue <- @venues} class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  <div class="flex items-center gap-2">
                    <span>{venue.name}</span>
                    <a
                      :if={venue.website}
                      href={venue.website}
                      target="_blank"
                      class="text-gray-400 hover:text-blue-600"
                      title={venue.website}
                    >
                      <.icon name="hero-globe-alt" class="size-4" />
                    </a>
                  </div>
                </td>
                <td class="px-6 py-4 text-sm text-gray-500">
                  <div :if={venue.address} class="whitespace-nowrap">{venue.address}</div>
                  <div class="whitespace-nowrap">
                    {format_location(venue)}
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <.link
                    navigate={~p"/admin/venues/#{venue.id}/edit"}
                    class="text-blue-600 hover:text-blue-900 mr-4"
                  >
                    Edit
                  </.link>
                  <button
                    phx-click="delete"
                    phx-value-id={venue.id}
                    data-confirm="Are you sure you want to delete this venue?"
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            </tbody>
          </table>

          <div :if={@venues == []} class="px-6 py-12 text-center text-gray-500">
            <p class="text-lg">No venues found</p>
            <p class="text-sm mt-2">Try adjusting your search or add a new venue</p>
          </div>
        </div>

        <div :if={@total_pages > 1} class="mt-6 flex items-center justify-between">
          <div class="text-sm text-gray-700">
            Showing page {@page} of {@total_pages} ({@total_count} total venues)
          </div>
          <div class="flex gap-2">
            <button
              :if={@page > 1}
              phx-click="prev_page"
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Previous
            </button>
            <button
              :if={@page < @total_pages}
              phx-click="next_page"
              class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700"
            >
              Next
            </button>
          </div>
        </div>
      </ShowcagoServicesWeb.AdminComponents.admin_layout>
    </Layouts.app>
    """
  end
end
