defmodule ShowcagoServicesWeb.Admin.UserLiveTest do
  use ShowcagoServicesWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Users
  alias ShowcagoServices.Users.User

  setup :register_and_log_in_admin_user

  test "renders users list", %{conn: conn} do
    regular_user = Users.get_user!(ShowcagoServices.UsersFixtures.user_fixture().id)

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    assert has_element?(view, "h1", "Users")
    assert has_element?(view, "#admin-user-#{regular_user.id}")
    assert has_element?(view, "#set-admin-#{regular_user.id}", "Make Admin")
  end

  test "can promote user to admin", %{conn: conn} do
    regular_user = Users.get_user!(ShowcagoServices.UsersFixtures.user_fixture().id)

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    view
    |> element("#set-admin-#{regular_user.id}")
    |> render_click()

    assert render(view) =~ "User role updated"
    assert Repo.get!(User, regular_user.id).role == :admin
  end

  test "cannot demote currently logged in admin", %{conn: conn, user: admin_user} do
    {:ok, view, _html} = live(conn, ~p"/admin/users")

    refute has_element?(view, "#set-user-#{admin_user.id}")
    refute render(view) =~ "Make User"

    assert Repo.get!(User, admin_user.id).role == :admin
  end

  test "can demote a different admin to user", %{conn: conn, user: logged_in_admin} do
    other_admin = ShowcagoServices.UsersFixtures.admin_user_fixture()

    assert other_admin.id != logged_in_admin.id

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    view
    |> element("#set-user-#{other_admin.id}")
    |> render_click()

    assert render(view) =~ "User role updated"
    assert Repo.get!(User, other_admin.id).role == :user
  end
end
