# Exclude integration tests by default (they require the full actor system)
# Run with: mix test --include integration
ExUnit.start(exclude: [:integration])
Ecto.Adapters.SQL.Sandbox.mode(Viban.Repo, :manual)
