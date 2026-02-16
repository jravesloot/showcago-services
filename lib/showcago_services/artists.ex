defmodule ShowcagoServices.Artists do
  @moduledoc """
  Artist domain queries and business logic.
  """

  import Ecto.Query, warn: false

  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Artist

  @default_limit 10
  @default_candidate_limit 50
  @max_match_text_length 500

  @type artist_match :: %{artist: Artist.t(), score: float()}

  @doc """
  Matches artists that appear inside a longer text string.

  Returns a list of maps in descending relevance:

      [%{artist: %Artist{}, score: 0.87}, ...]
  """
  @spec match_artists_in_text(binary(), keyword()) :: [artist_match()]
  def match_artists_in_text(text, opts \\ [])

  def match_artists_in_text(text, opts) when is_binary(text) do
    normalized_text = String.trim(text)

    if normalized_text == "" or String.length(normalized_text) > @max_match_text_length do
      []
    else
      limit = Keyword.get(opts, :limit, @default_limit)
      candidate_limit = max(limit, Keyword.get(opts, :candidate_limit, @default_candidate_limit))

      candidates =
        from(a in Artist,
          where:
            fragment(
              "lower(immutable_unaccent(?)) <% lower(immutable_unaccent(?))",
              a.name,
              ^normalized_text
            ),
          order_by: [
            desc:
              fragment(
                "word_similarity(lower(immutable_unaccent(?)), lower(immutable_unaccent(?)))",
                a.name,
                ^normalized_text
              ),
            asc: a.name
          ],
          limit: ^candidate_limit,
          select: %{
            artist: a,
            score:
              fragment(
                "word_similarity(lower(immutable_unaccent(?)), lower(immutable_unaccent(?)))",
                a.name,
                ^normalized_text
              )
          }
        )
        |> Repo.all()

      normalized_haystack = normalize_for_boundary_match(normalized_text)

      candidates
      |> Enum.filter(fn %{artist: artist} ->
        name_in_text?(artist.name, normalized_haystack)
      end)
      |> Enum.take(limit)
    end
  end

  def match_artists_in_text(_text, _opts), do: []

  defp name_in_text?(artist_name, normalized_haystack) do
    normalized_artist_name = normalize_for_boundary_match(artist_name)

    normalized_artist_name != "" and
      Regex.match?(
        ~r/(^|\s)#{Regex.escape(normalized_artist_name)}(\s|$)/u,
        normalized_haystack
      )
  end

  defp normalize_for_boundary_match(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}]+/u, " ")
    |> String.trim()
  end

  @spec list_artists(keyword()) :: [Artist.t()]
  def list_artists(opts \\ []) do
    search = Keyword.get(opts, :search)

    Artist
    |> maybe_search_artists(search)
    |> order_by([a], asc: a.name)
    |> Repo.all()
  end

  defp maybe_search_artists(query, nil), do: query
  defp maybe_search_artists(query, ""), do: query

  defp maybe_search_artists(query, search) do
    normalized_search = String.downcase(String.trim(search))

    from(a in query,
      where:
        fragment(
          "lower(immutable_unaccent(?)) % lower(immutable_unaccent(?))",
          a.name,
          ^normalized_search
        ),
      order_by: [
        desc:
          fragment(
            "similarity(lower(immutable_unaccent(?)), lower(immutable_unaccent(?)))",
            a.name,
            ^normalized_search
          )
      ]
    )
  end

  @spec get_artist!(term()) :: Artist.t()
  def get_artist!(id), do: Repo.get!(Artist, id)

  @spec create_artist(map()) :: {:ok, Artist.t()} | {:error, Ecto.Changeset.t()}
  def create_artist(attrs \\ %{}) do
    %Artist{}
    |> Artist.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_artist(Artist.t(), map()) :: {:ok, Artist.t()} | {:error, Ecto.Changeset.t()}
  def update_artist(%Artist{} = artist, attrs) do
    artist
    |> Artist.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_artist(Artist.t()) :: {:ok, Artist.t()} | {:error, Ecto.Changeset.t()}
  def delete_artist(%Artist{} = artist) do
    Repo.delete(artist)
  end

  @spec artist_changeset(Artist.t(), map()) :: Ecto.Changeset.t()
  def artist_changeset(%Artist{} = artist, attrs \\ %{}) do
    Artist.changeset(artist, attrs)
  end
end
