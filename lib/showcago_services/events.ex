defmodule ShowcagoServices.Events do
  @moduledoc """
  Event domain queries and business logic.
  """

  import Ecto.Query, warn: false

  alias ShowcagoServices.Events.Artist
  alias ShowcagoServices.Repo

  @default_limit 10
  @default_candidate_limit 50
  @max_match_text_length 500

  @doc """
  Matches artists that appear inside a longer text string.

  Returns a list of maps in descending relevance:

      [%{artist: %Artist{}, score: 0.87}, ...]
  """
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
        ~r/(^|\s)#{Regex.escape(normalized_artist_name)}(\s|$)/u, # match on whole words only, ignore accents and case
        normalized_haystack
      )
  end

  defp normalize_for_boundary_match(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}]+/u, " ") # remove non-alphanumeric characters, replace with space
    |> String.trim()
  end
end
