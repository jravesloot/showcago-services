defmodule ShowcagoServices.Jido.Actions.SendTelegramMessageAction do
  use Jido.Action,
    name: "send_telegram_message",
    description: "Sends a message to a Telegram chat.",
    schema: [
      chat_id: [
        type: :integer,
        required: true,
        doc: "The Telegram chat ID to send the message to"
      ],
      text: [type: :string, required: true, doc: "The message text to send"]
    ]

  @impl true
  def run(%{chat_id: chat_id, text: text}, _context) do
    token = Application.fetch_env!(:showcago_services, :telegram_bot_token)

    case Telegram.Api.request(token, "sendMessage",
           chat_id: chat_id,
           text: text,
           disable_web_page_preview: true
         ) do
      {:ok, _result} -> {:ok, %{}}
      {:error, reason} -> {:error, "Failed to send Telegram message: #{inspect(reason)}"}
    end
  end
end
