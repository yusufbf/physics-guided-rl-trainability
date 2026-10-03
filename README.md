# Physics-guided RL trainability: reproducibility companion

This is the private **V16 evidence-release candidate** for “Physics-Guided Task Formulation as a Trainability Prior for Reinforcement Learning in Autonomous Motion Planning.” It is under review and is **not yet the manuscript's public archival citation**. The `main` branch previously contained a V14-aligned audited partial release; this branch adds the archived raw evidence.

## Contents

- `code/primary/` and `code/ablation/`: archived MATLAB sources for 30 primary runs and 36 planned selective-ablation conditions. One historical SAC-A1-MS05 outcome is infrastructure-censored, not a completed 36th run.
- `results/`: audited run-level and paired summary tables.
- `raw_evidence/raw_mat/`: 65 training-stat and 47 executed 100-scenario final-test MAT files, mapped one-to-one to runs in `raw_evidence/raw_mat_manifest.csv`. All 112 copies matched the SHA-256 values in the audited ledgers.
- `raw_evidence/checkpoints/`: one recorded Stage-10 pass checkpoint for each of the 47 executed final tests; staged-file SHA-256 values are in `raw_evidence/checkpoint_manifest.csv`.
- `raw_evidence/scenario_bank/`: standalone 100-scenario final-test bank and representative validation banks. MATLAB R2024b found the final bank structurally identical in all 47 executed tests and classified the 65 embedded ten-stage validation banks into eight structural classes, consistent with the ledger identifiers. Independent regeneration from saved configuration and seeds matched all 21,172 recorded scenarios.
- `figures/`: summary-data figure reconstruction. The manuscript's embedded Figures 1 and 4 are the publication artwork; audit renditions need not be pixel-identical.

## Verify this candidate

Run `python verify_package.py` and `python raw_evidence/verify_raw_release.py` from a checkout of this branch. The raw-evidence verifier checks every staged file's size and SHA-256, counts and manifest uniqueness, plus the MATLAB bank-verification reports. Its success checks package integrity, not historical re-execution of training or deployment.

## Evidence limits before public release

The raw test and validation banks are included; cross-run identity and independent regeneration from the archived sampling rules, saved configuration, and seeds have been checked. Historical per-run executed-source self-hashes were not recorded; archived source equality cannot prove the exact bytes run historically. No end-to-end training rerun is claimed. Review data redistribution, license choice, an independent network checkout, MATLAB/toolbox compatibility, and figure correspondence before publicizing or issuing an archival DOI. See `metadata/RELEASE_STATUS.md` and `raw_evidence/README.md`.

The GF comparator was frozen after PG MS01–MS03 screening and before PG MS04–MS05 outcomes. Primary qualification counts are DDPG PG/GF 5/5 vs 1/5, TD3 5/5 vs 4/5, SAC 3/5 vs 4/5. The 27.99% median interaction reduction is conditional on seven jointly qualified seed pairs. Do not infer universal PG superiority or physical-robot safety from this simplified planar testbed.

