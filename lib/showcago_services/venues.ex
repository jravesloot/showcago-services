defmodule ShowcagoServices.Venues do
  @moduledoc """
  Venue domain queries and business logic.
  """

  import Ecto.Query, warn: false

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Venue

  @spec list_venues(keyword()) :: [Venue.t()]
  def list_venues(opts \\ []) do
    search = Keyword.get(opts, :search)
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset)

    Venue
    |> maybe_search_venues(search)
    |> order_by([v], asc: v.name)
    |> maybe_limit(limit)
    |> maybe_offset(offset)
    |> Repo.all()
  end

  @spec count_venues(keyword()) :: non_neg_integer()
  def count_venues(opts \\ []) do
    search = Keyword.get(opts, :search)

    Venue
    |> maybe_search_venues(search)
    |> exclude(:order_by)
    |> Repo.aggregate(:count, :id)
  end

  defp maybe_search_venues(query, nil), do: query
  defp maybe_search_venues(query, ""), do: query

  defp maybe_search_venues(query, search) do
    search_term = "%#{search}%"

    from(v in query,
      where:
        ilike(v.name, ^search_term) or
          ilike(v.city, ^search_term) or
          ilike(v.address, ^search_term)
    )
  end

  defp maybe_limit(query, nil), do: query

  defp maybe_limit(query, limit) when is_integer(limit) and limit > 0 do
    from(q in query, limit: ^limit)
  end

  defp maybe_limit(query, _invalid_limit), do: query

  defp maybe_offset(query, nil), do: query

  defp maybe_offset(query, offset) when is_integer(offset) and offset >= 0 do
    from(q in query, offset: ^offset)
  end

  defp maybe_offset(query, _invalid_offset), do: query

  @spec get_venue!(term()) :: Venue.t()
  def get_venue!(id), do: Repo.get!(Venue, id)

  @spec create_venue(map()) :: {:ok, Venue.t()} | {:error, Ecto.Changeset.t()}
  def create_venue(attrs \\ %{}) do
    %Venue{}
    |> Venue.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_venue(Venue.t(), map()) :: {:ok, Venue.t()} | {:error, Ecto.Changeset.t()}
  def update_venue(%Venue{} = venue, attrs) do
    venue
    |> Venue.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_venue(Venue.t()) :: {:ok, Venue.t()} | {:error, Ecto.Changeset.t()}
  def delete_venue(%Venue{} = venue) do
    Repo.delete(venue)
  end

  @spec venue_changeset(Venue.t(), map()) :: Ecto.Changeset.t()
  def venue_changeset(%Venue{} = venue, attrs \\ %{}) do
    Venue.changeset(venue, attrs)
  end
end
