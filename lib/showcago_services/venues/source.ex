defmodule ShowcagoServices.Venues.Source do
  @moduledoc """
  Behaviour for venue-specific schedule collection and event extraction.
  """

  alias ShowcagoServices.Schema.Venue

  @type extracted_event :: %{name: binary(), start_date: binary(), url: binary() | nil}

  @callback source_key() :: binary()
  @callback venue_name() :: binary()
  @callback default_refresh_interval_seconds() :: pos_integer()
  @callback collect_payload(Venue.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  @callback extract_events(binary()) :: [extracted_event()]
end
