# Archived MATLAB experiment sources

`primary/` contains 30 archived scripts and `ablation/` contains 36 planned scripts. `metadata/source_manifest.csv` records SHA-256 and the original filename for each. The named script for primary TD3-PG MS01 had two local copies with the same SHA-256; one byte-identical copy is deposited.

The scripts were copied byte-for-byte from the local experiment archive. They may contain machine-specific absolute paths. They are provided for implementation inspection and as a starting point for a documented rerun, **not** as a one-command exact historical replay. Source-to-output linkage is supported by archive names and hashes where recorded; no runtime self-hash proves the executable source bytes of each historical run. SAC-A1-MS05 has a local source hash computed during this package build, but its historical ledger did not record a source hash, and its experimental outcome remains censored.

Before rerunning, document MATLAB/Toolbox versions, required toolboxes, scenario-bank generation, seeds and random streams, output paths, checkpoint restoration, and validation behavior. Never overwrite the archived results.
