defmodule ShowcagoServices.TelegramBot do
  @moduledoc false
  use Telegram.Bot

  alias ShowcagoServices.Jido.ShowsAgent
  alias ShowcagoServices.Users

  require Logger

  @impl Telegram.Bot
  def handle_update(
        %{"message" => %{"chat" => %{"id" => chat_id}, "from" => %{"id" => telegram_id}, "text" => text}},
        _token
      )
      when is_integer(chat_id) and is_integer(telegram_id) and is_binary(text) do
    if Users.get_user_by_telegram_id(telegram_id) do
      Logger.warning("Received Telegram message: #{text} from telegram_id: #{telegram_id}, chat_id: #{chat_id}")

      forward_message_to_agent(telegram_id, chat_id, text)
    else
      Logger.warning("Ignoring Telegram message from unknown telegram_id: #{telegram_id}")
    end

    :ok
  end

  def handle_update(_update, _token), do: :ok

  defp forward_message_to_agent(telegram_id, chat_id, text) do
    agent_pid =
      case Jido.AgentServer.whereis(Jido.Registry, "shows_agent_#{telegram_id}") do
        nil ->
          # probably should use chat_id
          Logger.info("Starting new ShowsAgent for telegram_id: #{telegram_id}")

          {:ok, pid} =
            Jido.AgentServer.start_link(
              agent: ShowsAgent,
              id: "shows_agent_#{telegram_id}"
            )

          pid

        pid ->
          Logger.info("Found existing ShowsAgent for telegram_id: #{telegram_id}")
          pid
      end

    {:ok, response} =
      ShowsAgent.ask_sync(agent_pid, text, timeout: 60_000)

    ShowcagoServices.Jido.Actions.SendTelegramMessageAction.run(
      %{chat_id: chat_id, text: response},
      %{}
    )
  end
end
