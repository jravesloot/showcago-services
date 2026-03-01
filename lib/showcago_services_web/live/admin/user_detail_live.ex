defmodule ShowcagoServicesWeb.Admin.UserDetailLive do
  use ShowcagoServicesWeb, :live_view

  alias ShowcagoServices.Users

  def mount(%{"id" => id}, _session, socket) do
    user = Users.get_user!(id)

    {:ok,
     socket
     |> assign(:page_title, "User Detail")
     |> assign(:user, user)
     |> assign(:telegram_form, telegram_form(user))}
  end

  def handle_event("save-telegram-id", %{"user" => user_params}, socket) do
    case Users.update_user_telegram_id(socket.assigns.user, user_params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> assign(:telegram_form, telegram_form(updated_user))
         |> put_flash(:info, "User telegram id updated")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:telegram_form, to_form(changeset, as: :user))
         |> put_flash(:error, "Unable to update user telegram id")}
    end
  end

  def handle_event("set-role", %{"role" => role}, socket) do
    current_user = socket.assigns.current_scope.user
    selected_user = socket.assigns.user

    if self_demotion?(current_user, selected_user, role) do
      {:noreply, put_flash(socket, :error, "You cannot demote yourself")}
    else
      case Users.update_user_role(selected_user, %{role: role}) do
        {:ok, updated_user} ->
          {:noreply,
           socket
           |> assign(:user, updated_user)
           |> put_flash(:info, "User role updated")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Unable to update user role")}
      end
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]} full_width={true}>
      <ShowcagoServicesWeb.AdminComponents.admin_layout active_page={:users}>
        <div class="mb-6 flex items-center justify-between gap-4">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">User Detail</h1>
            <p class="mt-2 text-sm text-gray-600">Manage user access and Telegram integration</p>
          </div>

          <.link
            navigate={~p"/admin/users"}
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Back to Users
          </.link>
        </div>

        <div class="rounded-lg border border-slate-200 bg-white p-6 shadow-sm">
          <dl class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div>
              <dt class="text-xs font-semibold uppercase tracking-wide text-slate-500">Email</dt>
              <dd class="mt-1 text-sm text-slate-900">{@user.email}</dd>
            </div>
            <div>
              <dt class="text-xs font-semibold uppercase tracking-wide text-slate-500">Role</dt>
              <dd class="mt-1 text-sm text-slate-900">{@user.role}</dd>
              <div class="mt-3 flex items-center gap-2">
                <button
                  :if={@user.role != :admin}
                  id="set-admin"
                  type="button"
                  phx-click="set-role"
                  phx-value-role="admin"
                  class="px-3 py-1.5 text-xs font-medium text-blue-700 border border-blue-200 rounded-lg hover:bg-blue-50"
                >
                  Make Admin
                </button>

                <button
                  :if={@user.role != :user && !self?(@current_scope.user, @user)}
                  id="set-user"
                  type="button"
                  phx-click="set-role"
                  phx-value-role="user"
                  class="px-3 py-1.5 text-xs font-medium text-slate-700 border border-slate-300 rounded-lg hover:bg-slate-50"
                >
                  Make User
                </button>
              </div>
            </div>
          </dl>

          <div class="mt-6 border-t border-slate-200 pt-6">
            <h2 class="text-lg font-semibold text-slate-900">Telegram ID</h2>
            <p class="mt-1 text-sm text-slate-600">
              Set the Telegram user ID that is allowed to interact with the bot for this user.
            </p>

            <.form
              for={@telegram_form}
              id="telegram-id-form"
              phx-submit="save-telegram-id"
              class="mt-4 max-w-md"
            >
              <.input field={@telegram_form[:telegram_id]} type="number" min="1" label="Telegram ID" />

              <div class="mt-3 flex items-center gap-2">
                <button
                  id="save-telegram-id"
                  type="submit"
                  class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700"
                >
                  Save Telegram ID
                </button>
              </div>
            </.form>
          </div>
        </div>
      </ShowcagoServicesWeb.AdminComponents.admin_layout>
    </Layouts.app>
    """
  end

  defp telegram_form(user) do
    to_form(%{"telegram_id" => user.telegram_id}, as: :user)
  end

  defp self_demotion?(current_user, selected_user, role) do
    self?(current_user, selected_user) && role == "user"
  end

  defp self?(current_user, selected_user), do: current_user && current_user.id == selected_user.id
end
