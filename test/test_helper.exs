# Tests use Ecto SQL Sandbox for isolation
# Actor-heavy tests use async: false due to SQLite file-level locking
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Viban.RepoSqlite, :manual)
