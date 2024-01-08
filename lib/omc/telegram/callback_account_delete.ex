defmodule Omc.Telegram.CallbackAccountDelete do
  alias Omc.Servers
  use Omc.Telegram.CallbackQuery

  @impl true
  def do_process(args = %{callback_args: callback_args}) do
    case callback_args do
      [_sa_id, _sa_name, _sau_id | _actions] ->
        process(args)

      [] ->
        {:error, args |> Map.put(:message, "acc not specified")}

      _ ->
        {:redirect, "main", args |> Map.put(:message, "Bad args; redirected")}
    end
  end

  defp process(args = %{callback_args: [_sa_id, _sa_name, _sau_id]}) do
    {:ok,
     args
     |> Map.put_new(:message, "")}
  end

  defp process(args = %{callback_args: [sa_id, sa_name, sau_id | ["yes"]]}) do
    case sa_id
         |> Servers.get_server_acc!()
         |> Servers.deactivate_acc() do
      {:ok, _} ->
        {:redirect, "Account",
         args
         |> Map.put(:callback_args, [sa_id, sa_name, sau_id])
         |> Map.put(:message, "Account #{sa_name} registered for deletion.")}

      {:error, _} ->
        {:error, %{message: "Failed deactivating #{sa_name}"}}
    end
  end

  @impl true
  def get_text(%{
        callback_args: [_sa_id, sa_name, _sau_id]
      }) do
    ~s"""
    *Account Deletion Conformation*

    By deleting an account, the system stops billing for it and also it will not be possible to use it anymore.

    *Are you sure to delete account __#{sa_name}__?*

    """
  end

  @impl true
  def get_markup(%{callback_args: callback_args}) do
    [
      [
        markup_item(
          "Yes",
          TelegramUtils.encode_callback_data("AccountDelete", callback_args ++ ["yes"])
        )
      ],
      [
        markup_item(
          "No",
          TelegramUtils.encode_callback_data("Account", callback_args)
        )
      ]
    ]
  end
end
