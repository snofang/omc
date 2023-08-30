ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Omc.Repo, :manual)

Mox.defmock(Omc.CmdWrapperMock, for: Omc.Common.CmdWrapper)

