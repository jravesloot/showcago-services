defmodule ShowcagoServices.Shows do
  @moduledoc """
  Show domain queries and business logic.
  """

  import Ecto.Query, warn: false

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Show

  @spec list_upcoming_shows() :: [Show.t()]
  def list_upcoming_shows do
    now = DateTime.utc_now(:second)

    Show
    |> where([s], s.status == :upcoming and s.date >= ^now)
    |> order_by([s], asc: s.date)
    |> preload([:venue, :artists])
    |> Repo.all()
  end

  @spec list_upcoming_shows_grouped_by_date() :: [{Date.t(), [Show.t()]}]
  def list_upcoming_shows_grouped_by_date do
    list_upcoming_shows()
    |> Enum.group_by(&DateTime.to_date(&1.date))
    |> Enum.sort_by(fn {date, _shows} -> date end, Date)
  end
end
