defmodule Viban.MixProject do
  use Mix.Project

  def project do
    [
      app: :viban,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases()
    ]
  end

  defp releases do
    [
      viban: release_config()
    ]
  end

  defp release_config do
    base = [
      include_executables_for: [:unix],
      applications: [runtime_tools: :permanent]
    ]

    if System.get_env("BURRITO_BUILD") == "1" do
      # Single-binary build with Burrito (requires OTP <= 27 and zig installed)
      # Usage: BURRITO_BUILD=1 MIX_ENV=prod mix release
      # For specific target: BURRITO_BUILD=1 BURRITO_TARGET=macos_arm MIX_ENV=prod mix release
      base ++
        [
          steps: [:assemble, &Burrito.wrap/1],
          burrito: [
            targets: burrito_targets()
          ]
        ]
    else
      # Standard release (works with any OTP version)
      base
    end
  end

  defp burrito_targets do
    all_targets = [
      macos_arm: [os: :darwin, cpu: :aarch64],
      macos_intel: [os: :darwin, cpu: :x86_64],
      linux_arm: [os: :linux, cpu: :aarch64],
      linux_intel: [os: :linux, cpu: :x86_64]
    ]

    case System.get_env("BURRITO_TARGET") do
      nil ->
        all_targets

      "" ->
        all_targets

      target ->
        target_atom = String.to_atom(target)
        Keyword.take(all_targets, [target_atom])
    end
  end

  def application do
    [
      mod: {Viban.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.7.18"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:plug_cowboy, "~> 2.5"},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},

      # Database
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},

      # Ash Framework
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_typescript, "~> 0.2"},
      {:ash_ai, "~> 0.3"},

      # Phoenix Sync (Electric)
      {:electric, "~> 1.0"},
      {:phoenix_sync, "== 0.6.0"},

      # Ash Sync (Electric integration for Ash read queries)
      # {:ash_sync, github: "nxy7/ash_sync"},
      {:ash_sync, path: "/Users/dawiddanieluk/ash_sync"},

      # Utilities
      {:cors_plug, "~> 3.0"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:dns_cluster, "~> 0.1.1"},

      # Background Jobs
      {:oban, "~> 2.18"},
      {:oban_web, "~> 2.11"},

      # GitHub OAuth
      {:ueberauth, "~> 0.10"},
      {:ueberauth_github, "~> 0.8"},

      # HTTP Client for GitHub API
      {:req, "~> 0.5"},

      # Dev/Test
      {:floki, ">= 0.30.0", only: :test},
      {:tidewave, "~> 0.2", only: :dev},

      # Single-binary packaging
      {:burrito, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind viban", "esbuild viban"],
      "assets.deploy": [
        "tailwind viban --minify",
        "esbuild viban --minify",
        "phx.digest"
      ]
    ]
  end
end
