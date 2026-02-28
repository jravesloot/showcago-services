defmodule ShowcagoServicesWeb.Admin.UserLive do
  use ShowcagoServicesWeb, :live_view

  alias ShowcagoServices.Users

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> load_users()}
  end

  def handle_event("set-role", %{"id" => id, "role" => role}, socket) do
    user = Users.get_user!(id)
    current_user = socket.assigns.current_scope.user

    if self_demotion?(current_user, user, role) do
      {:noreply, put_flash(socket, :error, "You cannot demote yourself")}
    else
      case Users.update_user_role(user, %{role: role}) do
        {:ok, _updated_user} ->
          {:noreply,
           socket
           |> put_flash(:info, "User role updated")
           |> load_users()}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Unable to update user role")}
      end
    end
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
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
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
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button
                    :if={user.role != :admin}
                    id={"set-admin-#{user.id}"}
                    phx-click="set-role"
                    phx-value-id={user.id}
                    phx-value-role="admin"
                    class="text-blue-600 hover:text-blue-900 mr-4"
                  >
                    Make Admin
                  </button>

                  <button
                    :if={user.role != :user && !self?(@current_scope.user, user)}
                    id={"set-user-#{user.id}"}
                    phx-click="set-role"
                    phx-value-id={user.id}
                    phx-value-role="user"
                    class="text-slate-700 hover:text-slate-900"
                  >
                    Make User
                  </button>
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

  defp self_demotion?(current_user, selected_user, role) do
    self?(current_user, selected_user) && role == "user"
  end

  defp self?(current_user, selected_user), do: current_user && current_user.id == selected_user.id
end
