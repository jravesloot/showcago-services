defmodule ShowcagoServices.Jido.ShowsAgent do
  use Jido.AI.Agent,
    name: "shows_agent",
    description:
      "An agent that provides information about upcoming shows in Chicago, including details like date, venue, and artists.",
    model: :fast,
    max_iterations: 5,
    tools: [
      ShowcagoServices.Jido.Actions.ListShowsAction
    ],
    system_prompt: """
    You are a helpful assistant that provides information about upcoming shows
    in Chicago. You have access to a tool that can list upcoming shows with
    details like date, venue, and artists. When a user asks about upcoming
    shows, use the tool to get the latest information and share it in a clear
    and concise way.
    """

  # def init(_opts) do
  #   {:ok, %{history: []}}
  # end

  # TODO move to skill
  def handle_telegram_message(pid, chat_id, user_message, chat_token, opts \\ []) do
    {:ok, response} = __MODULE__.ask_sync(pid, user_message, Keyword.put_new(opts, :timeout, 60_000))

    Telegram.Api.request(chat_token, "sendMessage",
      chat_id: chat_id,
      text: response,
      disable_web_page_preview: true
    )

    :ok
  end

  # @impl true
  # def on_before_cmd(agent, {:react_start, params}) when is_map(params) do
  #   # You can modify the agent's state or perform actions before the command is executed
  #   user_message =
  #     Map.get(params, :prompt) ||
  #       Map.get(params, :query) ||
  #       Map.get(params, :message)

  #   history = agent.state.history || []
  #   prompt = build_prompt(history, user_message)
  #   updated_params = put_prompt(params, prompt)

  #   updated_state =
  #     if is_binary(user_message) do
  #       Map.put(agent.state, :history, history ++ [%{role: "user", content: user_message}])
  #     else
  #       agent.state
  #     end

  #   {:ok, %{agent | state: updated_state}, {:react_start, updated_params}}
  # end

  # @impl true
  # def on_before_cmd(agent, action), do: super(agent, action)

  # @impl true
  # def on_after_cmd(agent, _action, directives) do
  #   snap = strategy_snapshot(agent)

  #   updated_state =
  #     if snap.done? and is_binary(snap.result) do
  #       history = agent.state.history || []
  #       Map.put(agent.state, :history, history ++ [%{role: "assistant", content: snap.result}])
  #     else
  #       agent.state
  #     end

  #   {:ok, %{agent | state: updated_state}, directives}
  # end

  # defp build_prompt(history, user_message) when is_list(history) and is_binary(user_message) do
  #   history_text =
  #     history
  #     |> Enum.map(fn entry -> "#{entry.role}: #{entry.content}" end)
  #     |> Enum.join("\n")

  #   """
  #   Conversation history:
  #   #{history_text}

  #   user: #{user_message}
  #   """
  # end

  # defp build_prompt(_history, message), do: message

  # defp put_prompt(params, prompt) do
  #   cond do
  #     Map.has_key?(params, :prompt) -> Map.put(params, :prompt, prompt)
  #     Map.has_key?(params, :query) -> Map.put(params, :query, prompt)
  #     Map.has_key?(params, :message) -> Map.put(params, :message, prompt)
  #     true -> Map.put(params, :prompt, prompt)
  #   end
  # end
end
