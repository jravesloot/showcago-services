defmodule ShowcagoServices.Events do
  @moduledoc false

  alias ShowcagoServices.Artists
  alias ShowcagoServices.Schema.Artist
  alias ShowcagoServices.Venues
  alias ShowcagoServices.Schema.Venue

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

  @spec list_venues(keyword()) :: [Venue.t()]
  defdelegate list_venues(opts \\ []), to: Venues

  @spec get_venue!(term()) :: Venue.t()
  defdelegate get_venue!(id), to: Venues

  @spec create_venue(map()) :: {:ok, Venue.t()} | {:error, Ecto.Changeset.t()}
  defdelegate create_venue(attrs \\ %{}), to: Venues

  @spec update_venue(Venue.t(), map()) :: {:ok, Venue.t()} | {:error, Ecto.Changeset.t()}
  defdelegate update_venue(venue, attrs), to: Venues

  @spec delete_venue(Venue.t()) :: {:ok, Venue.t()} | {:error, Ecto.Changeset.t()}
  defdelegate delete_venue(venue), to: Venues

  @spec venue_changeset(Venue.t(), map()) :: Ecto.Changeset.t()
  defdelegate venue_changeset(venue, attrs \\ %{}), to: Venues
end
