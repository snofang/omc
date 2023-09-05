ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Omc.Repo, :manual)

Mox.defmock(Omc.CmdWrapperMock, for: Omc.Common.CmdWrapper)

Application.put_env(
  :omc,
  :cmd_wrapper,
  Application.put_env(:omc, :cmd_wrapper_impl, Omc.CmdWrapperMock)
)
