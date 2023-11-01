defmodule Omc.Payments.PaymentProvider do
  @callback send_payment_request(map()) ::
              {:ok, map()} | {:error, error_code :: binary()}

  @callback callback(params :: map(), body :: map()) ::
              {:ok, %{state: atom(), ref: binary(), data: map() | nil}, map() | binary()}
              | {:error, term()}

  @callback send_state_inquiry_request(ref :: binary()) ::
              {:ok, %{state: atom(), ref: binary(), data: map() | nil}}
              | {:error, term()}

  defmacro __using__(ipg) when is_atom(ipg) do
    quote do
      @behaviour Omc.Payments.PaymentProvider
      def api_key(), do: Application.get_env(:omc, :ipgs)[unquote(ipg)][:api_key]
      def timeout(), do: Application.get_env(:omc, :ipgs)[unquote(ipg)][:timeout]
      def callback_url(), do: OmcWeb.Endpoint.url() <> "/api/payment/" <> to_string(unquote(ipg))
      def return_url(), do: Application.get_env(:omc, :ipgs)[:return_url]
      def base_url(), do: Application.get_env(:omc, :ipgs)[unquote(ipg)][:base_url]
    end
  end

  def send_paymet_request(%{ipg: ipg} = attrs) do
    provider_impl(ipg).send_payment_request(attrs)
  end

  def callback(ipg, params, body) do
    provider_impl(ipg).callback(params, body)
  end

  def send_state_inquiry_request(ipg, ref) when is_binary(ref) and is_atom(ipg) do
    provider_impl(ipg).send_state_inquiry_request(ref)
  end

  defp provider_impl(ipg) when is_atom(ipg) do
    Application.get_env(:omc, :ipgs)[ipg][:module]
  end
end
