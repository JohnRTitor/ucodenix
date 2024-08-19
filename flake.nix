{
  description = "ucodenix flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      ucodenix =
        {
          cpuSerialNumber,
          amd-ucodegen ? self.packages.${system}.amd-ucodegen,
        }:
        pkgs.stdenv.mkDerivation {
          pname = "ucodenix";
          version = "1.0.0";

          src = pkgs.fetchFromGitHub {
            owner = "platomav";
            repo = "CPUMicrocodes";
            rev = "refs/heads/master";
            sha256 = "1gar3rpm4rijym7iljb25i4qxxjyj9c6wv39jhhhh70cip35gf97";
          };

          nativeBuildInputs = [ amd-ucodegen ];

          unpackPhase = ''
            runHook preUnpack
            mkdir -p $out
            serialResult=$(echo "${cpuSerialNumber}" | sed 's/.* = //;s/-0000.*//;s/-//')
            microcodeFile=$(find $src/AMD -name "cpu$serialResult*.bin" | head -n 1)
            cp $microcodeFile $out/$(basename $microcodeFile) || (echo "File not found: $microcodeFile" && exit 1)
            runHook postUnpack
          '';

          buildPhase = ''
            runHook preBuild
            mkdir -p $out/kernel/x86/microcode
            microcodeFile=$(find $out -name "cpu*.bin" | head -n 1)
            amd-ucodegen $microcodeFile
            mv microcode_amd*.bin $out/kernel/x86/microcode/AuthenticAMD.bin
            runHook postBuild
          '';

          dontInstall = true;

          meta = {
            description = "Generated AMD microcode for CPU";
            license = pkgs.lib.licenses.gpl3;
            platforms = pkgs.lib.platforms.linux;
          };
        };

    in
    {
      packages.x86_64-linux.default = self.packages.${system}.amd-ucodegen;
      packages.x86_64-linux.amd-ucodegen = pkgs.callPackage ./pkgs/amducodegen.nix { };

      nixosModules.ucodenix =
        {
          config,
          lib,
          pkgs,
          ...
        }:

        let
          cfg = config.services.ucodenix;
        in
        {
          options.services.ucodenix = {
            enable = lib.mkEnableOption "ucodenix service";

            cpuSerialNumber = lib.mkOption {
              type = lib.types.str;
              description = "The processor's serial number, used to determine the appropriate microcode binary file.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ (ucodenix { cpuSerialNumber = cfg.cpuSerialNumber; }) ];

            nixpkgs.overlays = [
              (final: prev: {
                microcodeAmd = prev.microcodeAmd.overrideAttrs (oldAttrs: {
                  buildPhase = ''
                    mkdir -p kernel/x86/microcode
                    cp ${
                      ucodenix { cpuSerialNumber = cfg.cpuSerialNumber; }
                    }/kernel/x86/microcode/AuthenticAMD.bin kernel/x86/microcode/AuthenticAMD.bin
                  '';
                });
              })
            ];
            assertions = [
              {
                assertion = cfg.cpuSerialNumber != "";
                message = "You must provide a CPU serial number to the ucodenix service.";
              }
            ];
          };
        };
    };
}
