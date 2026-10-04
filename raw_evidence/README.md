# V16 raw-evidence archive

This directory stages copies of the historical MAT evidence referenced by the audited primary and ablation ledgers. The local research archive was read, not changed. `raw_mat_manifest.csv` maps each copied file to its cohort, run, source path, ledger hash, and recorded scenario/configuration identifiers. `assembly_report.json` gives counts and copy/hash results.

The staged set contains 65 training-stat MAT files, 47 executed 100-scenario final-test MAT files, and 47 recorded Stage-10 pass checkpoints. All 112 copied raw-result files matched the hashes recorded in the ledgers at assembly; checkpoint hashes were computed on the staged copies. The infrastructure-censored SAC-A1-MS05 run remains censored; its recovery output has not been substituted.

MATLAB R2024b loaded all 47 executed final-test files. Each embedded 100 scenarios in `final10Scenarios`, and all 47 banks were structurally identical (`isequaln`). A standalone copy is in `scenario_bank/final10Scenarios.mat`; `bank_verification.csv` records the per-file check. MATLAB also loaded `stageValidationBanks` from all 65 training-stat MAT files: each had ten stage entries, and the complete banks fell into eight structural classes consistent with their ledger identifiers. Representative copies and the row-level class mapping are in `scenario_bank/`. Run `python verify_raw_release.py` to check the complete staged inventory and all file digests.

The independent MATLAB wrapper in `scenario_bank/regenerate_scenario_bank_v136.m` applies the archived sampling rules to the saved configuration and seeds. `regenerate_all_v16_banks.m` compared all 47 final-test banks and all nonempty stage-validation banks across 65 training runs: 21,172 scenarios checked, zero differences. The row-level results are in `scenario_bank/independent_regeneration.csv`.

**Open release checks:** Audit redistribution rights and any sensitive content; run an independent network checkout/build and document software dependencies. Historical per-run executed-source self-hashes were not recorded and must remain a stated provenance limit. No end-to-end training rerun has been verified by this staging step.

This archive is on the repository's public `main` branch. Cite an exact commit permalink for the version used; a Zenodo DOI should be cited only after the corresponding record is published and verified. The repository is `yusufbf/physics-guided-rl-trainability`.

