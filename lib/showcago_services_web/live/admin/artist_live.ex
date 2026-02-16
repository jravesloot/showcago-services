defmodule ShowcagoServicesWeb.Admin.ArtistLive do
  use ShowcagoServicesWeb, :live_view

  alias ShowcagoServices.Artists
  alias ShowcagoServices.Schema.Artist

  @per_page 50

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search, "")
     |> assign(:editing_artist_id, nil)
     |> assign(:form, nil)
     |> assign(:page, 1)
     |> assign(:per_page, @per_page)
     |> load_artists()}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Artists")
    |> assign(:editing_artist_id, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Artist")
    |> assign(:form, to_form(Artists.artist_changeset(%Artist{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    artist = Artists.get_artist!(id)

    socket
    |> assign(:page_title, "Edit Artist")
    |> assign(:editing_artist_id, String.to_integer(id))
    |> assign(:form, to_form(Artists.artist_changeset(artist)))
  end

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:search, search)
     |> assign(:page, 1)
     |> load_artists()}
  end

  def handle_event("next_page", _params, socket) do
    {:noreply,
     socket
     |> assign(:page, socket.assigns.page + 1)
     |> load_artists()}
  end

  def handle_event("prev_page", _params, socket) do
    {:noreply,
     socket
     |> assign(:page, max(socket.assigns.page - 1, 1))
     |> load_artists()}
  end

  def handle_event("validate", %{"artist" => artist_params}, socket) do
    changeset =
      if socket.assigns.editing_artist_id do
        artist = Artists.get_artist!(socket.assigns.editing_artist_id)
        Artists.artist_changeset(artist, artist_params)
      else
        Artists.artist_changeset(%Artist{}, artist_params)
      end

    {:noreply, assign(socket, :form, to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("save", %{"artist" => artist_params}, socket) do
    save_artist(socket, socket.assigns.live_action, artist_params)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    artist = Artists.get_artist!(id)

    case Artists.delete_artist(artist) do
      {:ok, _artist} ->
        {:noreply,
         socket
         |> put_flash(:info, "Artist deleted successfully")
         |> load_artists()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete artist")}
    end
  end

  defp save_artist(socket, :new, artist_params) do
    case Artists.create_artist(artist_params) do
      {:ok, _artist} ->
        {:noreply,
         socket
         |> put_flash(:info, "Artist created successfully")
         |> push_navigate(to: ~p"/admin/artists")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_artist(socket, :edit, artist_params) do
    artist = Artists.get_artist!(socket.assigns.editing_artist_id)

    case Artists.update_artist(artist, artist_params) do
      {:ok, _artist} ->
        {:noreply,
         socket
         |> put_flash(:info, "Artist updated successfully")
         |> push_navigate(to: ~p"/admin/artists")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp load_artists(socket) do
    total_count = Artists.count_artists(search: socket.assigns.search)
    per_page = socket.assigns.per_page
    total_pages = max(div(total_count + per_page - 1, per_page), 1)
    current_page = socket.assigns.page |> max(1) |> min(total_pages)
    offset = (current_page - 1) * per_page

    artists =
      Artists.list_artists(
        search: socket.assigns.search,
        limit: per_page,
        offset: offset
      )

    socket
    |> assign(:artists, artists)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
    |> assign(:page, current_page)
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Artists</h1>
        <p class="mt-2 text-sm text-gray-600">Manage artists for upcoming shows</p>
      </div>

      <%= if @live_action in [:new, :edit] do %>
        <div class="mb-8 bg-white shadow-sm rounded-lg p-6">
          <div class="mb-6">
            <h2 class="text-2xl font-bold text-gray-900">
              {@page_title}
            </h2>
          </div>

          <.form for={@form} id="artist-form" phx-change="validate" phx-submit="save">
            <div class="space-y-4">
              <div>
                <.input field={@form[:name]} type="text" label="Name" required />
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
                navigate={~p"/admin/artists"}
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
            placeholder="Search artists..."
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </form>

        <.link
          navigate={~p"/admin/artists/new"}
          class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
        >
          Add Artist
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
                Website
              </th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr :for={artist <- @artists} class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                {artist.name}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <a
                  :if={artist.website}
                  href={artist.website}
                  target="_blank"
                  class="text-blue-600 hover:text-blue-800"
                >
                  {artist.website}
                </a>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <.link
                  navigate={~p"/admin/artists/#{artist.id}/edit"}
                  class="text-blue-600 hover:text-blue-900 mr-4"
                >
                  Edit
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={artist.id}
                  data-confirm="Are you sure you want to delete this artist?"
                  class="text-red-600 hover:text-red-900"
                >
                  Delete
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <div :if={@artists == []} class="px-6 py-12 text-center text-gray-500">
          <p class="text-lg">No artists found</p>
          <p class="text-sm mt-2">Try adjusting your search or add a new artist</p>
        </div>

        <div :if={@total_count > 0} class="px-6 py-4 border-t border-gray-200 bg-gray-50">
          <div class="flex items-center justify-between gap-4">
            <p class="text-sm text-gray-600">
              Showing page {@page} of {@total_pages} ({@total_count} artists)
            </p>

            <div class="flex items-center gap-2">
              <button
                type="button"
                phx-click="prev_page"
                disabled={@page == 1}
                class="px-3 py-2 text-sm font-medium rounded-lg border border-gray-300 bg-white text-gray-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-100"
              >
                Previous
              </button>
              <button
                type="button"
                phx-click="next_page"
                disabled={@page >= @total_pages}
                class="px-3 py-2 text-sm font-medium rounded-lg border border-gray-300 bg-white text-gray-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-100"
              >
                Next
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
