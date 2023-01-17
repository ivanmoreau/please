{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      perSystem = { self', pkgs, lib, config, system, ... }: {
        packages.please-build = pkgs.stdenv.mkDerivation {
          name = "please-build";
          src = self;
          depsBuildBuild = with pkgs; [ go makeWrapper ];
          buildPhase = ''
            export HOME=$(pwd)
            go run -race src/please.go $PLZ_ARGS --log_file plz-out/log/bootstrap_build.log build //src:please
            plz-out/bin/src/please build //package:installed_files
          '';
          installPhase = ''
            mkdir -p $out/.please
            OUTPUTS="`plz-out/bin/src/please query outputs //package:installed_files`"
            for OUTPUT in $OUTPUTS; do
              TARGET="$out/.please/$(basename $OUTPUT)"
              rm -f "$TARGET"  # Important so we don't write through symlinks.
              cp $OUTPUT $TARGET
              chmod 0775 $TARGET
            done
            chmod 0664 "$out/.please/junit_runner.jar"
            mkdir -p $out/bin
            makeWrapper $out/.please/please $out/bin/please
            makeWrapper $out/.please/please $out/bin/please-build
          '';
        };

        packages.default = self'.packages.please-build;
      };
    };
}
