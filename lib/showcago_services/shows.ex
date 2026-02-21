defmodule ShowcagoServices.Shows do
  @moduledoc """
  Show domain queries and business logic.
  """

  import Ecto.Query, warn: false

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Show

  @chicago_time_zone "America/Chicago"

  @spec get_show!(term()) :: Show.t()
  def get_show!(id), do: Repo.get!(Show, id)

  @spec set_show_ignored(Show.t(), boolean()) :: {:ok, Show.t()} | {:error, Ecto.Changeset.t()}
  def set_show_ignored(%Show{} = show, ignored) when is_boolean(ignored) do
    show
    |> Show.changeset(%{ignored: ignored})
    |> Repo.update()
  end

  @spec list_upcoming_shows(keyword()) :: [Show.t()]
  def list_upcoming_shows(opts \\ []) do
    now = DateTime.utc_now(:second)
    include_ignored = Keyword.get(opts, :include_ignored, false)

    Show
    |> where([s], s.status == :upcoming and s.date >= ^now)
    |> maybe_exclude_ignored(include_ignored)
    |> order_by([s], asc: s.date)
    |> preload([:venue, :artists])
    |> Repo.all()
  end

  @spec list_upcoming_shows_grouped_by_date(keyword()) :: [{Date.t(), [Show.t()]}]
  def list_upcoming_shows_grouped_by_date(opts \\ []) do
    list_upcoming_shows(opts)
    |> Enum.group_by(&chicago_local_date(&1.date))
    |> Enum.sort_by(fn {date, _shows} -> date end, Date)
  end

  defp maybe_exclude_ignored(query, true), do: query

  defp maybe_exclude_ignored(query, false) do
    where(query, [s], s.ignored == false)
  end

  defp chicago_local_date(%DateTime{} = datetime) do
    case DateTime.shift_zone(datetime, @chicago_time_zone) do
      {:ok, shifted_datetime} -> DateTime.to_date(shifted_datetime)
      _ -> DateTime.to_date(datetime)
    end
  end
end
