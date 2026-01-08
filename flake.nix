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
          # Use Erlang 27 for Burrito compatibility (OTP 28 ERTS not yet on BEAM Machine)
          erlang = pkgs.erlang_27;
          beamPackages = pkgs.beam.packagesWith erlang;
          elixir = beamPackages.elixir_1_18;

          # Map Nix system to Burrito target
          burritoTarget = {
            "x86_64-linux" = "linux_intel";
            "aarch64-linux" = "linux_arm";
            "x86_64-darwin" = "macos_intel";
            "aarch64-darwin" = "macos_arm";
          }.${system} or (throw "Unsupported system: ${system}");
        in
        {
          packages.default = pkgs.stdenv.mkDerivation {
            pname = "viban";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = [
              erlang
              elixir
              pkgs.bun
              pkgs.zig
              pkgs.xz
              pkgs.git
              pkgs.cacert
              pkgs.just
              pkgs.gnumake
            ];

            SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
            HOME = "/tmp";
            MIX_ENV = "prod";
            BURRITO_TARGET = burritoTarget;

            buildPhase = ''
              runHook preBuild

              # Setup mix
              mix local.hex --force
              mix local.rebar --force

              # Use justfile build recipe
              just build ${burritoTarget} true

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin
              cp backend/burrito_out/viban_${burritoTarget} $out/bin/viban

              runHook postInstall
            '';
          };

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
