{
  description = "Data / neural analysis Python (mne, neo, pandas, scikit-learn, jupyter)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      # Match the system list used across this repo's dev shells.
      systems = [ "aarch64-darwin" "x86_64-linux" "x86_64-darwin" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          python = pkgs.python3.withPackages (ps: with ps; [
            # general numerical / plotting
            numpy
            scipy
            pandas
            matplotlib
            seaborn
            scikit-learn
            h5py

            # neural / electrophysiology + behavioral analysis
            mne
            neo

            jupyterlab

            # NOTE: PsychoPy and pylink (SR Research EyeLink SDK) are NOT in
            # nixpkgs. They are for experiment *collection*, not analysis. If a
            # project needs them, layer a uv venv on top of this shell:
            #   uv venv && uv pip install psychopy
            #   pylink ships with the EyeLink Developers Kit — install by hand.
          ]);
        in {
          default = pkgs.mkShell {
            packages = [
              python
              pkgs.ruff          # linter + formatter
              pkgs.basedpyright  # language server
            ];
          };
        });
    };
}
