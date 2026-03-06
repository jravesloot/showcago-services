defmodule ShowcagoServices.Workers.DispatchCollectionWorker do
  @moduledoc """
  Cron-triggered Oban worker that dispatches one `CollectVenueSourceWorker`
  job per configured source module.
  """

  use Oban.Worker, queue: :collection, max_attempts: 1

  alias ShowcagoServices.Workers.CollectVenueSourceWorker

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    source_modules = ShowcagoServices.Venues.source_modules()
    Logger.info("[dispatcher] dispatching #{length(source_modules)} collection jobs")

    for source_module <- source_modules do
      %{"source_key" => source_module.source_key()}
      |> CollectVenueSourceWorker.new()
      |> Oban.insert()
    end

    :ok
  end
end
