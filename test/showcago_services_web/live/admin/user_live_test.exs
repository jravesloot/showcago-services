defmodule ShowcagoServicesWeb.Admin.UserLiveTest do
  use ShowcagoServicesWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ShowcagoServices.Users

  setup :register_and_log_in_admin_user

  test "renders users list", %{conn: conn} do
    regular_user = Users.get_user!(ShowcagoServices.UsersFixtures.user_fixture().id)
    {:ok, regular_user} = Users.update_user_telegram_id(regular_user, %{telegram_id: 123_456})

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    assert has_element?(view, "h1", "Users")
    assert has_element?(view, "#admin-user-#{regular_user.id}")
    assert has_element?(view, "#admin-user-#{regular_user.id}", "123456")
    assert has_element?(view, "#edit-user-#{regular_user.id}", "Edit")
  end

  test "navigates to user detail page", %{conn: conn} do
    regular_user = Users.get_user!(ShowcagoServices.UsersFixtures.user_fixture().id)

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    assert has_element?(
             view,
             "#edit-user-#{regular_user.id}[href='/admin/users/#{regular_user.id}']"
           )
  end
end
