defmodule ShowcagoServices.Events do
  @moduledoc false

  alias ShowcagoServices.Artists
  alias ShowcagoServices.Schema.Artist

  @spec match_artists_in_text(binary(), keyword()) :: [Artists.artist_match()]
  defdelegate match_artists_in_text(text, opts \\ []), to: Artists

  @spec list_artists(keyword()) :: [Artist.t()]
  defdelegate list_artists(opts \\ []), to: Artists

  @spec get_artist!(term()) :: Artist.t()
  defdelegate get_artist!(id), to: Artists

  @spec create_artist(map()) :: {:ok, Artist.t()} | {:error, Ecto.Changeset.t()}
  defdelegate create_artist(attrs \\ %{}), to: Artists

  @spec update_artist(Artist.t(), map()) :: {:ok, Artist.t()} | {:error, Ecto.Changeset.t()}
  defdelegate update_artist(artist, attrs), to: Artists

  @spec delete_artist(Artist.t()) :: {:ok, Artist.t()} | {:error, Ecto.Changeset.t()}
  defdelegate delete_artist(artist), to: Artists

  @spec artist_changeset(Artist.t(), map()) :: Ecto.Changeset.t()
  defdelegate artist_changeset(artist, attrs \\ %{}), to: Artists
end
