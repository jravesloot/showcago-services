defmodule ShowcagoServices.Jido.Actions.IgnoreShowAction do
  @moduledoc false
  use Jido.Action,
    name: "ignore_show",
    description: "Marks a show as ignored so it will be excluded from upcoming show listings.",
    schema: [
      show_id: [type: :integer, required: true, doc: "The ID of the show to ignore"]
    ]

  require Logger

  @impl true
  def run(%{show_id: show_id}, _context) do
    show = ShowcagoServices.Shows.get_show!(show_id)

    Logger.warning("Ignoring show #{show.id}: #{show.notes} (#{show.date})")

    case ShowcagoServices.Shows.set_show_ignored(show, true) do
      {:ok, _show} -> {:ok, %{message: "Show #{show_id} has been marked as ignored."}}
      {:error, changeset} -> {:error, "Failed to ignore show: #{inspect(changeset.errors)}"}
    end
  end
end
