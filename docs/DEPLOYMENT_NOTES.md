# Deployment Notes

## Current Approach

Using Docker Compose for local development and distribution:
- Postgres runs in Docker
- Elixir app runs natively on host (required for executor access to host tools)
- Frontend runs natively

This is necessary because executors (Claude Code, Codex, etc.) need access to:
- Host filesystem (code repositories)
- Host-installed CLI tools (git, claude, codex, etc.)
- User credentials and SSH keys

## Future: Single Binary Distribution

When ready to pursue "download and run" distribution, here's the researched approach:

### Architecture

| Component | Solution |
|-----------|----------|
| Elixir app | [Burrito](https://github.com/burrito-elixir/burrito) or [Bakeware](https://github.com/bake-bake-bake/bakeware) |
| Postgres | Bundle binaries, spawn via Elixir Port |
| Data | `~/.viban/` for DB data + config |

### Embedded Postgres Options

1. **Rust: `postgresql_embedded`** - https://github.com/theseus-rs/postgresql-embedded
   - `bundled` feature embeds Postgres binaries at compile time
   - Cross-platform: Linux, macOS, Windows
   - ~10MB binary addition
   - Postgres runs as separate process, not in-process

2. **Go: `embedded-postgres`** - https://pkg.go.dev/github.com/fergusstrange/embedded-postgres
   - Uses zonkyio pre-compiled binaries
   - Same approach as Rust option

3. **Java: Zonky** - https://github.com/zonkyio/embedded-postgres
   - The original implementation, provides lightweight binaries

### Elixir Implementation Pattern

```elixir
defmodule Viban.EmbeddedPostgres do
  def start do
    # Extract bundled postgres binary to temp location
    pg_bin = extract_postgres_binary()
    data_dir = Path.expand("~/.viban/data")

    # Initialize data directory if needed
    unless File.exists?(data_dir) do
      System.cmd(Path.join(pg_bin, "initdb"), ["-D", data_dir])
    end

    # Start postgres as a Port (separate OS process)
    port = Port.open({:spawn_executable, Path.join(pg_bin, "postgres")}, [
      :binary,
      :exit_status,
      args: [
        "-D", data_dir,
        "-p", "5432",
        "-c", "wal_level=logical",           # Required for Electric SQL
        "-c", "max_wal_senders=10",
        "-c", "max_replication_slots=10"
      ]
    ])

    # Wait for ready, then Postgrex connects normally
    wait_for_postgres()
  end
end
```

### Key Considerations

- **Electric SQL requires** `wal_level=logical` - embedded Postgres supports this via startup flags
- **Platform-specific binaries** - need separate releases for linux-amd64, linux-arm64, darwin-amd64, darwin-arm64, windows
- **Estimated binary size** - ~50-80MB total (Elixir release + Postgres)

### User Experience Goal

```bash
# Download single binary for their platform
curl -L https://releases.viban.io/viban-macos-arm64 -o viban
chmod +x viban
./viban  # Starts everything, opens browser at localhost:8000
```

### Why Docker Socket Mounting is Fine

Originally concerned about security of mounting Docker socket, but:
- The app already runs arbitrary CLI commands by design
- If app is compromised, attacker has host access either way
- This is a trusted single-user/team dev tool, not multi-tenant

The practical challenges with Docker are path mapping and tool availability, not security.

## References

- Elixir Ports: https://hexdocs.pm/elixir/Port.html
- Bakeware: https://github.com/bake-bake-bake/bakeware
- Burrito: https://github.com/burrito-elixir/burrito
- Zonky binaries: https://github.com/zonkyio/embedded-postgres-binaries
