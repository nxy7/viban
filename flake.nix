{
  description = "Viban - Fast-iteration task management tool";
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix2container.url = "github:nlewo/nix2container";
  };

  outputs =
    { flake-parts, nixpkgs, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        { config, system, ... }:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        let
          # Use Erlang 27 for Burrito compatibility (OTP 28 ERTS not yet on BEAM Machine)
          erlang = pkgs.erlang_27;
          beamPackages = pkgs.beam.packagesWith erlang;
          elixir = beamPackages.elixir_1_18;
        in
        {
          devShells.default = pkgs.mkShell {
            packages = [
              # Build tools
              pkgs.just
              pkgs.overmind
              pkgs.zig
              pkgs.xz

              # Elixir/Erlang (pinned to OTP 27 for Burrito builds)
              erlang
              elixir

              # Node.js / Bun
              pkgs.bun
            ];
          };
        };
    };
}
