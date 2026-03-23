{
  description = "Crator (with nix run .#crator wrapper)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};

      waiting = pkgs.python3Packages.buildPythonPackage rec {
        pname = "waiting";
        version = "1.4.1";
        src = pkgs.fetchPypi {
          inherit pname version;
          sha256 = "sha256-tkHvOiOC4QHTxOZklNpvxSuCwyXdBK40HgUbDuxvMM0=";
        };

        pyproject = true;
        build-system = [pkgs.python3Packages.setuptools];

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

      cratorWrapper = pkgs.writeShellApplication {
        name = "crator";
        runtimeInputs = [pkgs.coreutils pkgs.yq-go];
        text = ''
          set -euo pipefail

          seed_url=""
          depth=""
          data_dir=""
          http_proxy=""

          while [ $# -gt 0 ]; do
            case "$1" in
              --seed-url) seed_url="$2"; shift 2;;
              --depth) depth="$2"; shift 2;;
              --data-dir) data_dir="$2"; shift 2;;
              --http-proxy) http_proxy="$2"; shift 2;;
              --) shift; break;;
              *) break;;
            esac
          done

          tmp="$(mktemp -d)"
          trap 'rm -rf "$tmp"' EXIT
          mkdir -p "$tmp/resources"
          cp -r resources/. "$tmp/resources/"

          [ -n "$seed_url" ] && printf '%s\n' "$seed_url" > "$tmp/resources/seeds.txt"

          # default output directory to ./out (relative to where you ran nix run)
          inv_pwd="$(pwd)"
          : "''${data_dir:="$inv_pwd/out"}"
          case "$data_dir" in /*) ;; *) data_dir="$inv_pwd/$data_dir";; esac

          cfg="$tmp/resources/crator.yml"

          # yq env()/strenv() only reads exported env vars, not shell vars
          export data_dir
          yq -i '.data_directory = strenv(data_dir)' "$cfg"

          if [ -n "$depth" ]; then
            export depth
            yq -i '.["crawler.depth"] = (env(depth) | tonumber)' "$cfg"
          fi

          if [ -n "$http_proxy" ]; then
            export http_proxy
            yq -i '.http_proxy = strenv(http_proxy)' "$cfg"
          fi

          cd "$tmp"
          exec ${crator}/bin/crator "$@"
        '';
      };
    in {
      packages = {
        default = crator;
        crator = crator;
        crator-wrapped = cratorWrapper;
      };

      apps = {
        default = flake-utils.lib.mkApp {drv = crator;};
        crator = flake-utils.lib.mkApp {drv = crator;};
        crator-wrapper = flake-utils.lib.mkApp {drv = cratorWrapper;};
      };

      devShells.default = pkgs.mkShell {
        packages = [pythonEnv pkgs.tor];
      };
    });
}
