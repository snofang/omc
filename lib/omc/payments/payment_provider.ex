defmodule Omc.Payments.PaymentProvider do
  @callback send_payment_request(map()) ::
              {:ok, map()} | {:error, error_code :: binary()}

  @callback callback(data :: binary()) ::
              {:ok, call_info :: %{state: atom(), ref: binary(), data: map()},
               response :: map() | binary()}
              | {:error, term()}

  @callback send_state_inquiry_request(ref :: binary()) ::
              {:ok, call_info :: %{state: atom(), data: map()}}
              | {:error, term()}

  @callback get_paid_money!(data :: map(), currency :: atom()) :: Money.t()

  defmacro __using__(ipg) when is_atom(ipg) do
    quote do
      @behaviour Omc.Payments.PaymentProvider
      def api_key(), do: Application.get_env(:omc, :ipgs)[unquote(ipg)][:api_key]
      def timeout(), do: Application.get_env(:omc, :ipgs)[unquote(ipg)][:timeout]

      def callback_url(),
        do:
          (Application.get_env(:omc, :ipgs)[:callback_base_url] ||
             OmcWeb.Endpoint.url()) <> "/api/payment/" <> to_string(unquote(ipg))

      def return_url(), do: Application.get_env(:omc, :ipgs)[:return_url]
      def base_url(), do: Application.get_env(:omc, :ipgs)[unquote(ipg)][:base_url]
    end
  end

  def send_paymet_request(%{ipg: ipg} = attrs) do
    provider_impl(ipg).send_payment_request(attrs)
  end

  def callback(ipg, data) do
    provider_impl(ipg).callback(data)
  end

  def send_state_inquiry_request(ipg, ref) when is_binary(ref) and is_atom(ipg) do
    provider_impl(ipg).send_state_inquiry_request(ref)
  end

  @doc """
  Extracts actual paid money, from the `data` optained in last `:done` state, received 
  for a payment request via inquiry or callback.
  The `currency` is the one internally registered in `PaymentRequest` and passed as
  a check to verify if it is equal to the actual currency received.
  """
  @spec get_paid_money!(atom(), map(), atom()) :: Money.t()
  def get_paid_money!(ipg, %{} = data, currency)
      when is_atom(ipg) and is_atom(currency) do
    provider_impl(ipg).get_paid_money!(data, currency)
  end

  defp provider_impl(ipg) when is_atom(ipg) do
    Application.get_env(:omc, :ipgs)[ipg][:module]
  end
end
