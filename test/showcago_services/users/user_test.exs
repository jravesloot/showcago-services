defmodule ShowcagoServices.Users.UserTest do
  use ExUnit.Case, async: true

  alias ShowcagoServices.Users.User

  describe "role_changeset/2" do
    test "accepts valid role" do
      changeset = User.role_changeset(%User{}, %{role: :admin})

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :role) == :admin
    end

    test "requires role" do
      changeset = User.role_changeset(%User{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).role
    end

    test "rejects invalid role" do
      changeset = User.role_changeset(%User{}, %{role: :super_admin})

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
