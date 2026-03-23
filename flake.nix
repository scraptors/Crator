{  
  description = "A flake for managing Crator with a CLI wrapper";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
  };
  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.crator = nixpkgs.legacyPackages.x86_64-linux.mkDerivation {  
      pname = "crator";
      version = "1.0.0";
      src = ./.;
      nativeBuildInputs = [ pkgs.coreutils pkgs.gawk pkgs.gnused ];
      buildInputs = [ pkgs.yq-go ];
      installPhase = ''
          mkdir -p $out/bin
          cp -R ${src}/bin/crator $out/bin/
      '';  
    };

    apps.default = {  
      type = "app";
      program = "${self.packages.x86_64-linux.crator}/bin/crator";
    };

    # New CLI Wrapper
    apps.crator = {  
      type = "app";
      program = ''
        pkgs.writeShellApplication {  
          name = "crator";
          runtimeInputs = [ pkgs.coreutils pkgs.gnused pkgs.gawk pkgs.yq-go ];

          # Define arguments
          args = ''
            --seed-url=
            --depth=
            --data-dir=
            --http-proxy=
          '';

          script = ''
            #!/bin/sh
            set -e

            # Create temporary working directory
            temp_dir=$(mktemp -d)
            mkdir -p "$temp_dir/resources"

            # Copy resources
            cp resources/seeds.txt "$temp_dir/resources/"
            cp resources/crator.yml "$temp_dir/resources/"

            # Modify the YAML configurations based on CLI arguments
            sed -i "s|^crawler.depth: .*|crawler.depth: ${depth}|' "$temp_dir/resources/crator.yml"
            sed -i "s|^data_directory: .*|data_directory: ${data_dir}|' "$temp_dir/resources/crator.yml"
            sed -i "s|^http_proxy: .*|http_proxy: ${http_proxy}|' "$temp_dir/resources/crator.yml"
            echo "${seed_url}" > "$temp_dir/resources/seeds.txt"

            # Execute crator binary
            cd "$temp_dir"
            ${self.packages.x86_64-linux.crator}/bin/crator
          '';
        };
      '';
    };
  }
}