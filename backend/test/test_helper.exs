# All tests run by default now that async is properly supported
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Viban.RepoSqlite, :manual)
