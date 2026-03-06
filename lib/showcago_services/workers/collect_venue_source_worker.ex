defmodule ShowcagoServices.Workers.CollectVenueSourceWorker do
  @moduledoc """
  Oban worker that collects data for a single venue source identified by
  `source_key`. On failure, triggers the CodeAgent to investigate and
  potentially open a GitHub issue or PR.
  """

  use Oban.Worker,
    queue: :collection,
    max_attempts: 3,
    unique: [fields: [:args, :queue, :worker], states: [:available, :scheduled, :executing]]

  alias ShowcagoServices.Jido.CodeAgent

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"source_key" => source_key}}) do
    Logger.info("[collector] collecting source=#{source_key}")

    case ShowcagoServices.Venues.collect_schedule_payload_for_source(source_key, force: false) do
      {:ok, _venue, :updated} ->
        Logger.warning("[collector] source=#{source_key} result=updated")
        ShowcagoServices.Venues.parse_schedule_payload_and_create_shows_for_source(source_key)

      {:ok, _venue, :skipped} ->
        Logger.warning("[collector] source=#{source_key} result=skipped (not stale)")
        :ok

      {:error, reason} ->
        Logger.warning("[collector] source=#{source_key} failed=#{inspect(reason)}")
        trigger_code_agent(source_key, reason)
        {:error, {source_key, reason}}
    end
  end

  defp trigger_code_agent(source_key, reason) do
    Task.Supervisor.start_child(
      ShowcagoServices.TaskSupervisor,
      fn ->
        Logger.warning("[collector] triggering CodeAgent for source=#{source_key}")

        {:ok, pid} =
          Jido.AgentServer.start_link(
            agent: CodeAgent,
            id: "code_agent_collector_#{source_key}_#{System.system_time(:second)}"
          )

        prompt = """
        The venue source "#{source_key}" failed during scheduled data collection.

        Error: #{inspect(reason, limit: 1000)}

        Please investigate this failure:
        1. Read the source module file for "#{source_key}" from the repo
        2. Read the Source behaviour to understand the expected interface
        4. If the fix is straightforward (e.g. a changed API URL, updated venue ID, or
           response format change), also create a branch, commit the fix, and open a PR
           referencing the issue.
        3. Otherwise, open a GitHub issue describing the failure, including the error details and
           the source key. Use the label "bug" if available.
        """

        case CodeAgent.ask_sync(pid, prompt, timeout: 120_000) do
          {:ok, response} ->
            Logger.warning("[collector] CodeAgent response for source=#{source_key}: #{response}")

          {:error, agent_error} ->
            Logger.warning("[collector] CodeAgent failed for source=#{source_key}: #{inspect(agent_error)}")
        end
      end
    )
  end
end
