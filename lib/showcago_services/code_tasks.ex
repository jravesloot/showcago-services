defmodule ShowcagoServices.CodeTasks do
  @moduledoc """
  In-memory GenServer that tracks CodeAgent task submissions and their results.
  Tasks are lost on application restart.
  """

  use GenServer

  alias ShowcagoServices.Jido.CodeAgent

  require Logger

  @pubsub ShowcagoServices.PubSub
  @topic "code_tasks"
  @agent_timeout 120_000

  defstruct tasks: %{}, task_order: []

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Submits a prompt to the CodeAgent. Returns the created task immediately.
  The agent runs asynchronously in the background.
  """
  @spec submit_task(binary()) :: {:ok, map()}
  def submit_task(prompt) when is_binary(prompt) do
    GenServer.call(__MODULE__, {:submit_task, prompt})
  end

  @doc """
  Returns all tasks ordered newest-first.
  """
  @spec list_tasks() :: [map()]
  def list_tasks do
    GenServer.call(__MODULE__, :list_tasks)
  end

  @doc """
  Returns a single task by ID, or nil.
  """
  @spec get_task(binary()) :: map() | nil
  def get_task(id) when is_binary(id) do
    GenServer.call(__MODULE__, {:get_task, id})
  end

  @doc """
  Subscribe to task update events via PubSub.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  # --- Server callbacks ---

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:submit_task, prompt}, _from, state) do
    id = generate_id()
    now = DateTime.utc_now(:second)

    task = %{
      id: id,
      prompt: prompt,
      status: :pending,
      response: nil,
      error: nil,
      submitted_at: now,
      completed_at: nil
    }

    state = %{state | tasks: Map.put(state.tasks, id, task), task_order: [id | state.task_order]}

    broadcast({:task_submitted, task})
    run_agent_async(id, prompt)

    {:reply, {:ok, task}, state}
  end

  def handle_call(:list_tasks, _from, state) do
    tasks = Enum.map(state.task_order, &Map.fetch!(state.tasks, &1))
    {:reply, tasks, state}
  end

  def handle_call({:get_task, id}, _from, state) do
    {:reply, Map.get(state.tasks, id), state}
  end

  @impl true
  def handle_info({:task_running, id}, state) do
    state = update_task(state, id, fn task -> %{task | status: :running} end)
    broadcast({:task_updated, Map.get(state.tasks, id)})
    {:noreply, state}
  end

  def handle_info({:task_completed, id, response}, state) do
    state =
      update_task(state, id, fn task ->
        %{task | status: :completed, response: response, completed_at: DateTime.utc_now(:second)}
      end)

    broadcast({:task_updated, Map.get(state.tasks, id)})
    {:noreply, state}
  end

  def handle_info({:task_failed, id, error}, state) do
    state =
      update_task(state, id, fn task ->
        %{task | status: :failed, error: error, completed_at: DateTime.utc_now(:second)}
      end)

    broadcast({:task_updated, Map.get(state.tasks, id)})
    {:noreply, state}
  end

  # --- Private helpers ---

  defp run_agent_async(task_id, prompt) do
    server = self()

    Task.Supervisor.start_child(ShowcagoServices.TaskSupervisor, fn ->
      send(server, {:task_running, task_id})

      agent_id = "code_agent_task_#{task_id}"

      case Jido.AgentServer.start_link(agent: CodeAgent, id: agent_id) do
        {:ok, pid} ->
          case CodeAgent.ask_sync(pid, prompt, timeout: @agent_timeout) do
            {:ok, response} ->
              Logger.info("[code_tasks] task=#{task_id} completed")
              send(server, {:task_completed, task_id, response})

            {:error, reason} ->
              Logger.warning("[code_tasks] task=#{task_id} agent_error=#{inspect(reason)}")
              send(server, {:task_failed, task_id, inspect(reason, limit: 500)})
          end

        {:error, reason} ->
          Logger.warning("[code_tasks] task=#{task_id} start_error=#{inspect(reason)}")
          send(server, {:task_failed, task_id, inspect(reason, limit: 500)})
      end
    end)
  end

  defp update_task(state, id, update_fn) do
    case Map.get(state.tasks, id) do
      nil -> state
      task -> %{state | tasks: Map.put(state.tasks, id, update_fn.(task))}
    end
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, message)
  end

  defp generate_id do
    Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end
end
