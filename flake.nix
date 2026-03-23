{
  description = "Crator — Tor hidden service crawler";

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
    flake-utils.lib.eachDefaultSystem (
      system: let
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
            beautifulsoup4
            pyyaml
            lxml
            fake-useragent
            stem
            urllib3
            pysocks
            waiting
          ]);

        crator = pkgs.stdenv.mkDerivation {
          pname = "crator";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [pkgs.makeWrapper];

          installPhase = ''
            runHook preInstall

            install -d $out/bin $out/share/crator

            # Python sources live in python/ subdirectory
            cp -rT python $out/share/crator

            # Resources live at the repo root, always copy separately
            cp -r resources $out/share/crator/resources

            makeWrapper ${pythonEnv}/bin/python3 $out/bin/crator \
              --add-flags "$out/share/crator/crator.py"

            runHook postInstall
          '';

          meta = {
            description = "A Python-based Tor hidden service crawler";
            mainProgram = "crator";
          };
        };

        cratorWrapper = pkgs.writeShellApplication {
          name = "crator-wrapper";
          runtimeInputs = [pkgs.coreutils pkgs.yq-go];

          text = ''
            seed_url="" depth="" data_dir="" http_proxy=""

            while [[ $# -gt 0 ]]; do
              case "$1" in
                --seed-url)   seed_url="$2";  shift 2 ;;
                --depth)      depth="$2";     shift 2 ;;
                --data-dir)   data_dir="$2";  shift 2 ;;
                --http-proxy) http_proxy="$2"; shift 2 ;;
                --)           shift; break ;;
                *)            break ;;
              esac
            done

            tmp=$(mktemp -d)
            trap 'rm -rf "$tmp"' EXIT

            cp -rT ${crator}/share/crator "$tmp"
            chmod -R u+w "$tmp"

            cfg="$tmp/resources/crator.yml"

            # Resolve data_dir to absolute path
            invocation_pwd=$(pwd)
            data_dir=''${data_dir:-"$invocation_pwd/out"}
            [[ "$data_dir" == /* ]] || data_dir="$invocation_pwd/$data_dir"

            export data_dir
            yq -i '.data_directory = strenv(data_dir)' "$cfg"

            if [[ -n "$seed_url" ]]; then
              printf '%s\n' "$seed_url" > "$tmp/resources/seeds.txt"
            fi

            if [[ -n "$depth" ]]; then
              export depth
              yq -i '.["crawler.depth"] = (env(depth) | tonumber)' "$cfg"
            fi

            if [[ -n "$http_proxy" ]]; then
              export http_proxy
              yq -i '.http_proxy = strenv(http_proxy)' "$cfg"
            fi

            cd "$tmp"
            exec ${pythonEnv}/bin/python3 "$tmp/crator.py" "$@"
          '';
        };
      in {
        packages = {
          default = cratorWrapper;
          crator = crator;
          crator-wrapper = cratorWrapper;
        };

        apps = {
          default = flake-utils.lib.mkApp {drv = cratorWrapper;};
          crator = flake-utils.lib.mkApp {drv = crator;};
          crator-wrapper = flake-utils.lib.mkApp {drv = cratorWrapper;};
        };

        devShells.default = pkgs.mkShell {
          packages = [pythonEnv pkgs.tor pkgs.yq-go];
        };
      }
    );
}
