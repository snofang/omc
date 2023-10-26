defmodule Omc.Payments.PaymentProvider do
  @callback send_payment_request(%{money: Money.t(), ref: binary()}) ::
              {:ok, url :: binary()} | {:error, error_code :: binary()}

  def send_paymet_request(ipg, attrs = %{money: _, ref: _}) do
    provider_impl(ipg).send_payment_request(attrs)
  end

  def callback(ipg, params, body) do
    provider_impl(ipg).callback(params, body)
  end

  defp provider_impl(ipg) when is_atom(ipg) do
    Application.get_env(:omc, :ipgs)[ipg][:module]
  end
end
