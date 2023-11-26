defmodule Omc.Payments do
  use GenServer
  require Logger
  alias Omc.Ledgers
  alias Omc.Payments.{PaymentRequest, PaymentState}
  alias Omc.Payments.PaymentProvider
  import Ecto.Query
  alias Omc.Repo
  import Ecto.Query.API, only: [max: 1, ago: 2, like: 2], warn: false

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
  @spec callback(atom(), map()) :: {:ok, term()} | {:error, term()}
  def callback(ipg, data) do
    case PaymentProvider.callback(ipg, data) do
      {:ok, state_attrs = %{ref: ref, state: _state, data: _date}, res} ->
        get_payment_request(ref)
        |> case do
          nil ->
            {:error, :not_found}

          pr ->
            {:ok, ps} = insert_payment_state(pr, state_attrs)
            if ps.state == :done, do: update_ledger(pr, ps)
            {:ok, res}
        end

      {:error, res} ->
        {:error, res}
    end
  end

  @spec send_state_inquiry_request(%PaymentRequest{}) :: {:ok, %PaymentState{}} | {:error, term()}
  def send_state_inquiry_request(%PaymentRequest{} = pr) do
    PaymentProvider.send_state_inquiry_request(pr.ipg, pr.ref)
    |> case do
      {:ok, state_attrs} ->
        {:ok, ps} = insert_payment_state(pr, state_attrs)
        if ps.state == :done, do: update_ledger(pr, ps)
        {:ok, ps}

      {:error, e} ->
        {:error, e}
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

  # @doc """
  # Finds all payments which have got `:done` state within last `duration` in seconds.
  # """
  # @spec update_ledgers(integer()) :: :ok
  # def update_ledgers(duration) when is_integer(duration) do
  #   Logger.info("-- update payments --")
  #
  #   duration
  #   |> get_payments_with_last_done_state()
  #   |> Enum.each(fn i ->
  #     try do
  #       update_ledger(i)
  #     rescue
  #       any_exception ->
  #         Logger.info(~s(
  #           Updating ledger by payment, failed
  #           {payment_request, payment_state}:
  #             #{inspect(i)}
  #           reason: 
  #             #{inspect(any_exception)}))
  #     end
  #   end)
  #
  #   :ok
  # end

  @doc false
  # Updates user's ledger with the paid amount. It first checks if this payment has already 
  # caused ledger change or not. In case of already affected ledger, do nothing and returns success. 
  @spec __update_ledger__!({%PaymentRequest{}, %PaymentState{}}) ::
          {:ok, :ledger_updated} | {:ok, :ledger_unchanged}
  def __update_ledger__!({pr, ps}) when ps.state == :done do
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

  @spec list_payment_requests(Keyword.t()) :: list(%PaymentRequest{})
  def list_payment_requests(args) do
    args = Keyword.validate!(args, page: 1, limit: 10, user_id: nil, user_type: nil, state: nil)

    list_payment_requests_query()
    |> list_payment_requests_where_user_type(args[:user_type])
    |> list_payment_requests_where_user_id(args[:user_id])
    |> list_payment_requests_where_state(args[:state])
    |> offset((^args[:page] - 1) * ^args[:limit])
    |> limit(^args[:limit])
    |> order_by(desc: :id)
    |> Repo.all()
  end

  defp list_payment_requests_where_user_type(query, user_type) when user_type == nil, do: query

  defp list_payment_requests_where_user_type(query, user_type),
    do: query |> where(user_type: ^user_type)

  defp list_payment_requests_where_user_id(query, user_id) when user_id == nil, do: query

  defp list_payment_requests_where_user_id(query, user_id),
    do: query |> where([pr], like(pr.user_id, ^"%#{user_id}%"))

  defp list_payment_requests_where_state(query, state) when state == nil, do: query

  defp list_payment_requests_where_state(query, state),
    do: query |> where([payment_state: ps], ps.state == ^state)

  defp list_payment_requests_query() do
    last_payment_state =
      from(ps in PaymentState,
        group_by: ps.payment_request_id,
        select: %{id: max(ps.id), payment_request_id: ps.payment_request_id}
      )

    from(pr in PaymentRequest,
      left_join: ls in subquery(last_payment_state),
      on: ls.payment_request_id == pr.id,
      left_join: ps in PaymentState,
      as: :payment_state,
      on: ps.id == ls.id,
      select: %{pr | state: ps.state}
    )
  end

  def get_payment_request!(id) do
    PaymentRequest
    |> where(id: ^id)
    |> preload(:payment_states)
    |> Repo.one!()
  end

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def init(init_args) do
    {:ok, init_args}
  end

  def handle_call({:update_ledger, pr_ps}, _from, state) do
    {:reply, __update_ledger__!(pr_ps), state}
  end

  @spec update_ledger(%PaymentRequest{}, %PaymentState{}) ::
          {:ok, :ledger_updated} | {:ok, :ledger_unchanged}
  def update_ledger(payment_request, payment_state) when payment_state.state == :done do
    GenServer.call(__MODULE__, {:update_ledger, {payment_request, payment_state}})
  end

  # def create_payment_request_samples() do
  #   1..100
  #   |> Enum.each(fn _ ->
  #     %{
  #       user_id: Ecto.UUID.generate(),
  #       user_type: :telegram,
  #       money: Money.new(System.unique_integer()),
  #       ipg: :oxapay
  #     }
  #     |> Map.put(:data, %{"some_data_key" => "some_data_key_value"})
  #     |> Map.put(:ref, Ecto.UUID.generate())
  #     |> Map.put(:url, "https://example.com/pay/")
  #     |> Map.put(:type, :push)
  #     |> PaymentRequest.create_changeset()
  #     |> Repo.insert()
  #     |> then(fn {:ok, pr} ->
  #       %{payment_request_id: pr.id, state: :pending, data: %{some_data: "some_valye"}}
  #       |> PaymentState.create_changeset()
  #       |> Repo.insert()
  #
  #       %{payment_request_id: pr.id, state: :failed, data: %{some_data: "some_failed"}}
  #       |> PaymentState.create_changeset()
  #       |> Repo.insert()
  #     end)
  #   end)
  # end
end
