ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Omc.Repo, :manual)

#
# Defining mock implementation for CmdWrapper.
#
Mox.defmock(Omc.CmdWrapperMock, for: Omc.Common.CmdWrapper)

Application.put_env(:omc, :cmd_wrapper_impl, Omc.CmdWrapperMock)

#
# Defining mock implementation of wp payment provider.
#
Mox.defmock(Omc.PaymentProviderMock, for: Omc.Payments.PaymentProvider)

Application.put_env(
  :omc,
  :ipgs,
  Application.get_env(:omc, :ipgs) |> put_in([:wp, :module], Omc.PaymentProviderMock)
)
