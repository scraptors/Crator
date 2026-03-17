{
  description = "Crator - Dark Web Crawler";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    utils,
    ...
  }:
    utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};

      waiting = pkgs.python3Packages.buildPythonPackage rec {
        pname = "waiting";
        version = "1.4.1";

        src = pkgs.fetchPypi {
          inherit pname version;
          sha256 = "sha256-tkHvOiOC4QHTxOZklNpvxSuCwyXdBK40HgUbDuxvMM0="; # replace with real hash on first build
        };

        doCheck = false;
      };

      pythonEnv = pkgs.python3.withPackages (ps:
        with ps; [
          requests
          pysocks
          beautifulsoup4
          pyyaml
          lxml
          fake-useragent
          stem
          urllib3
          waiting
        ]);

      crator = pkgs.stdenv.mkDerivation {
        pname = "crator";
        version = "0.1.0";

        src = ./.;

        nativeBuildInputs = [pkgs.makeWrapper];
        buildInputs = [pythonEnv];

        installPhase = ''
          mkdir -p $out/bin $out/share/crator
          cp -r python/* $out/share/crator/
          makeWrapper ${pythonEnv}/bin/python3 $out/bin/crator \
            --add-flags "$out/share/crator/crator.py"
        '';

        meta = {
          description = "A Python-based Tor hidden service crawler";
          mainProgram = "crator";
        };
      };
    in {
      packages = {
        inherit crator;
        default = crator;
      };

      apps.default = utils.lib.mkApp {
        drv = crator;
      };

      devShells.default = pkgs.mkShell {
        packages = [pythonEnv pkgs.tor];
      };
    });
}
