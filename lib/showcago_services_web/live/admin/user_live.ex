defmodule ShowcagoServicesWeb.Admin.UserLive do
  @moduledoc false
  use ShowcagoServicesWeb, :live_view

  alias ShowcagoServices.Users

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> load_users()}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]} full_width={true}>
      <ShowcagoServicesWeb.AdminComponents.admin_layout active_page={:users}>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Users</h1>
          <p class="mt-2 text-sm text-gray-600">Manage user access roles</p>
        </div>

        <div class="bg-white shadow-sm rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Email
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Role
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Telegram ID
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr :for={user <- @users} id={"admin-user-#{user.id}"} class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {user.email}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-700">
                  {user.role}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-700">
                  {if(user.telegram_id, do: user.telegram_id, else: "—")}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <.link
                    id={"edit-user-#{user.id}"}
                    navigate={~p"/admin/users/#{user.id}"}
                    class="inline-flex items-center rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50"
                  >
                    Edit
                  </.link>
                </td>
              </tr>
            </tbody>
          </table>

          <div :if={@users == []} class="px-6 py-12 text-center text-gray-500">
            <p class="text-lg">No users found</p>
          </div>
        </div>
      </ShowcagoServicesWeb.AdminComponents.admin_layout>
    </Layouts.app>
    """
  end

  defp load_users(socket) do
    assign(socket, :users, Users.list_users())
  end
end
