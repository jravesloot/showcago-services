defmodule ShowcagoServices.Workers.DispatchCollectionWorkerTest do
  use ShowcagoServices.DataCase, async: true
  use Oban.Testing, repo: ShowcagoServices.Repo

  alias ShowcagoServices.Workers.CollectVenueSourceWorker
  alias ShowcagoServices.Workers.DispatchCollectionWorker

  describe "perform/1" do
    test "returns :ok" do
      assert :ok = perform_job(DispatchCollectionWorker, %{})
    end

    test "enqueues one CollectVenueSourceWorker job per source module" do
      perform_job(DispatchCollectionWorker, %{})

      for source_module <- ShowcagoServices.Venues.source_modules() do
        assert_enqueued(
          worker: CollectVenueSourceWorker,
          args: %{"source_key" => source_module.source_key()}
        )
      end
    end

    test "enqueues the correct number of jobs" do
      perform_job(DispatchCollectionWorker, %{})

      expected_count = length(ShowcagoServices.Venues.source_modules())
      jobs = all_enqueued(worker: CollectVenueSourceWorker)

      assert length(jobs) == expected_count
    end
  end
end
