{
  description = "Video project preliminary eye-tracking analysis";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-linux" "x86_64-darwin" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          python = pkgs.python3.withPackages (ps: with ps; [
            numpy
            scipy
            pandas
            matplotlib
            seaborn
            scikit-learn
            h5py
            mne
            neo
            jupyterlab
            nbconvert
            ipykernel
          ]);
        in {
          default = pkgs.mkShell {
            packages = [
              python
              pkgs.zsh
              pkgs.ruff
              pkgs.basedpyright
            ];

            shellHook = ''
              export JUPYTER_PATH="$PWD/.jupyter''${JUPYTER_PATH:+:$JUPYTER_PATH}"
            '';
          };
        });
    };
}
