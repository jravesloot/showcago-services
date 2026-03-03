defmodule ShowcagoServices.TelegramBot do
  use Telegram.Bot

  alias ShowcagoServices.Users
  require Logger

  @impl Telegram.Bot
  def handle_update(
        %{
          "message" => %{
            "chat" => %{"id" => chat_id},
            "from" => %{"id" => telegram_id},
            "text" => text
          }
        },
        token
      )
      when is_integer(chat_id) and is_integer(telegram_id) and is_binary(text) do
    if Users.get_user_by_telegram_id(telegram_id) do
      Logger.info(
        "Received Telegram message: #{text} from telegram_id: #{telegram_id}, chat_id: #{chat_id}"
      )

      forward_message_to_agent(telegram_id, chat_id, text, token)
    else
      Logger.warning("Ignoring Telegram message from unknown telegram_id: #{telegram_id}")
    end

    :ok
  end

  def handle_update(_update, _token), do: :ok

  defp forward_message_to_agent(telegram_id, chat_id, text, token) do
    agent_pid =
      case Jido.AgentServer.whereis(Jido.Registry, "shows_agent_#{telegram_id}") do
        nil ->
          # probably should use chat_id
          Logger.info("Starting new ShowsAgent for telegram_id: #{telegram_id}")

          {:ok, pid} =
            Jido.AgentServer.start_link(
              agent: ShowcagoServices.Jido.ShowsAgent,
              id: "shows_agent_#{telegram_id}"
            )

          pid

        pid ->
          Logger.info("Found existing ShowsAgent for telegram_id: #{telegram_id}")
          pid
      end

    ShowcagoServices.Jido.ShowsAgent.handle_telegram_message(agent_pid, chat_id, text, token)
  end
end
