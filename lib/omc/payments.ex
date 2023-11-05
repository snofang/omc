defmodule Omc.Payments do
  require Logger
  alias Omc.Ledgers
  alias Omc.Payments.{PaymentRequest, PaymentState}
  alias Omc.Payments.PaymentProvider
  import Ecto.Query
  alias Omc.Repo
  import Ecto.Query.API, only: [max: 1, ago: 2], warn: false

  def create_payment_request(ipg, %{user_id: user_id, user_type: user_type, money: money}) do
    %{
      user_id: user_id,
      user_type: user_type,
      money: money,
      ipg: ipg
    }
    |> PaymentProvider.send_paymet_request()
    |> case do
      {:ok, params} ->
        PaymentRequest.create_changeset(params)
        |> Repo.insert()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles callback from an `ipg` and creates new status update record related 
  to already existing `Omc.Payments.PaymentRequest`

  The callback is normally a web api call, it receives both `params` and `body` of given call 
  and passes them to underliying provider for detail processing and calculating resulted 
  new status.
    
  returns response used to be returned as the web api requestd callback.
  """
  @spec callback(atom(), map(), map() | nil) :: {:ok, term()} | {:error, term()}
  def callback(ipg, params, body) do
    case PaymentProvider.callback(ipg, params, body) do
      {:ok, state_attrs = %{ref: ref, state: _state, data: _date}, res} ->
        get_payment_request(ref)
        |> case do
          nil ->
            {:error, :not_found}

          request ->
            {:ok, _state} = insert_payment_state(request, state_attrs)
            {:ok, res}
        end

      {:error, res} ->
        {:error, res}
    end
  end

  defp insert_payment_state(payment_request, attrs) do
    attrs
    |> Map.put(:payment_request_id, payment_request.id)
    |> PaymentState.create_changeset()
    |> Repo.insert()
  end

  @doc """
  Gets `Omc.Payments.PaymentRequest` by `ref` if exists or nil.
  """
  @spec get_payment_request(binary()) :: %PaymentRequest{} | nil
  def get_payment_request(ref) when is_binary(ref) do
    PaymentRequest
    |> where(ref: ^ref)
    |> preload(:payment_states)
    |> Repo.one()
  end

  @doc """
  Finds all payments which have got `:done` state within last `duration` in seconds.
  """
  @spec update_ledgers(integer()) :: :ok
  def update_ledgers(duration) when is_integer(duration) do
    Logger.info("-- update payments --")
    duration
    |> get_payments_with_last_done_state()
    |> Enum.each(fn i ->
      try do
        update_ledger(i)
      rescue
        any_exception ->
          Logger.info(~s(
            Updating ledger by payment, failed
            {payment_request, payment_state}:
              #{inspect(i)}
            reason: 
              #{inspect(any_exception)}))
      end
    end)

    :ok
  end

  @doc false
  # Updates user's ledger with the paid amount. It first checks if this payment has already 
  # affected or not. In case of already affected ledger, do nothing and returns success. 
  @spec update_ledger({%PaymentRequest{}, %PaymentState{}}) ::
          {:ok, :ledger_updated} | {:ok, :ledger_unchanged}
  def update_ledger({pr, ps}) when ps.state == :done do
    case Ledgers.get_ledger_tx_by_context(:payment, pr.id) do
      nil ->
        Ledgers.create_ledger_tx!(%{
          user_id: pr.user_id,
          user_type: pr.user_type,
          context: :payment,
          context_id: pr.id,
          money: PaymentProvider.get_paid_money!(pr.ipg, ps.data, pr.money.currency),
          type: :credit
        })

        {:ok, :ledger_updated}

      _already_existing_ledger_tx ->
        {:ok, :ledger_unchanged}
    end
  end

  @doc false
  def get_payments_with_last_done_state(duration) when is_integer(duration) do
    last_done_payment_state =
      from(ps in PaymentState,
        where: ps.state == :done and ps.inserted_at > ago(^duration, "second"),
        group_by: ps.payment_request_id,
        select: %{id: max(ps.id), payment_request_id: ps.payment_request_id}
      )

    from(pr in PaymentRequest,
      join: ldps in subquery(last_done_payment_state),
      on: ldps.payment_request_id == pr.id,
      join: ps in PaymentState,
      on: ldps.id == ps.id,
      order_by: [asc: pr.id],
      select: {pr, ps}
    )
    |> Repo.all()
  end
end
