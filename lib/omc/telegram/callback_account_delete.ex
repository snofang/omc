defmodule Omc.Telegram.CallbackAccountDelete do
  alias Omc.Servers
  use Omc.Telegram.CallbackQuery
  import Omc.Gettext

  @impl true
  def do_process(args = %{callback_args: callback_args}) do
    case callback_args do
      [_s_id, _sa_id, _sau_id, _s_tag | _actions] ->
        process(args)

      [] ->
        {:error, args |> Map.put(:message, "acc not specified")}

      _ ->
        {:redirect, "main", args |> Map.put(:message, "Bad args; redirected")}
    end
  end

  defp process(args = %{callback_args: [_s_id, _sa_id, _sau_id, _s_tag]}) do
    {:ok,
     args
     |> Map.put_new(:message, "")}
  end

  defp process(args = %{callback_args: [s_id, sa_id, sau_id, s_tag | ["yes"]]}) do
    case sa_id
         |> Servers.get_server_acc!()
         |> Servers.deactivate_acc() do
      {:ok, _} ->
        {:redirect, "Account",
         args
         |> Map.put(:callback_args, [s_id, sa_id, sau_id, s_tag])
         |> Map.put(
           :message,
           TelegramUtils.sa_name(sa_id, s_tag) <> gettext("registered for deletion.")
         )}

      {:error, _} ->
        {:error,
         message:
           dgettext("errors", "Failed deactivating: ") <> TelegramUtils.sa_name(sa_id, s_tag)}
    end
  end

  @impl true
  def get_text(%{
        callback_args: [_s_id, sa_id, _sau_id, s_tag]
      }) do
    ~s"""
    __*#{gettext("Account Deletion Conformation")}*__

    #{gettext("By deleting an account, the system stops billing for it and also it will not be possible to use it anymore.")}

    *#{gettext("Are you sure to delete the following account?")} __#{TelegramUtils.sa_name(sa_id, s_tag)}__*

    """
  end

  @impl true
  def get_markup(%{callback_args: callback_args}) do
    [
      [
        markup_item(
          gettext("Yes"),
          TelegramUtils.encode_callback_data("AccountDelete", callback_args ++ ["yes"])
        )
      ],
      [
        markup_item(
          gettext("No"),
          TelegramUtils.encode_callback_data("Account", callback_args)
        )
      ]
    ]
  end
end
