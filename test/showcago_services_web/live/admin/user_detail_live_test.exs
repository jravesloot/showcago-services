defmodule ShowcagoServicesWeb.Admin.UserDetailLiveTest do
  use ShowcagoServicesWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Users
  alias ShowcagoServices.Users.User

  setup :register_and_log_in_admin_user

  test "renders user detail page", %{conn: conn} do
    regular_user = Users.get_user!(ShowcagoServices.UsersFixtures.user_fixture().id)

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{regular_user.id}")

    assert has_element?(view, "h1", "User Detail")
    assert has_element?(view, "#telegram-id-form")
    assert has_element?(view, "#save-telegram-id", "Save Telegram ID")
    assert has_element?(view, "#set-admin", "Make Admin")
  end

  test "can promote user to admin", %{conn: conn} do
    regular_user = Users.get_user!(ShowcagoServices.UsersFixtures.user_fixture().id)

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{regular_user.id}")

    view
    |> element("#set-admin")
    |> render_click()

    assert render(view) =~ "User role updated"
    assert Repo.get!(User, regular_user.id).role == :admin
  end

  test "can demote a different admin to user", %{conn: conn, user: logged_in_admin} do
    other_admin = ShowcagoServices.UsersFixtures.admin_user_fixture()

    assert other_admin.id != logged_in_admin.id

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{other_admin.id}")

    view
    |> element("#set-user")
    |> render_click()

    assert render(view) =~ "User role updated"
    assert Repo.get!(User, other_admin.id).role == :user
  end

  test "cannot demote currently logged in admin", %{conn: conn, user: admin_user} do
    {:ok, view, _html} = live(conn, ~p"/admin/users/#{admin_user.id}")

    refute has_element?(view, "#set-user")
    assert Repo.get!(User, admin_user.id).role == :admin
  end

  test "can update telegram id for a user", %{conn: conn} do
    regular_user = Users.get_user!(ShowcagoServices.UsersFixtures.user_fixture().id)

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{regular_user.id}")

    view
    |> form("#telegram-id-form", %{"user" => %{"telegram_id" => "123456"}})
    |> render_submit()

    assert render(view) =~ "User telegram id updated"
    assert Repo.get!(User, regular_user.id).telegram_id == 123_456
  end

  test "rejects duplicate telegram id", %{conn: conn} do
    existing_user = Users.get_user!(ShowcagoServices.UsersFixtures.user_fixture().id)
    {:ok, existing_user} = Users.update_user_telegram_id(existing_user, %{telegram_id: 333_444})

    regular_user = Users.get_user!(ShowcagoServices.UsersFixtures.user_fixture().id)
    assert existing_user.id != regular_user.id

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{regular_user.id}")

    view
    |> form("#telegram-id-form", %{
      "user" => %{"telegram_id" => Integer.to_string(existing_user.telegram_id)}
    })
    |> render_submit()

    assert render(view) =~ "Unable to update user telegram id"
    assert Repo.get!(User, regular_user.id).telegram_id == nil
  end
end
