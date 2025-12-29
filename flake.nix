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
        {
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              # Build tools
              just
              overmind

              # Elixir/Erlang
              elixir_1_19
              erlang_27

              # Node.js / Bun
              bun
            ];

          };
        };
    };
}
