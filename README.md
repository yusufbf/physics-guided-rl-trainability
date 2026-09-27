# Reproducibility Package

**Article:** Physics-Guided Task Formulation as a Trainability Prior for Reinforcement Learning in Autonomous Motion Planning  
**Prepared:** 27 September 2026  
**Package version:** v1 (partial-evidence assembly)

## Purpose
This repository is the reproducibility companion to the manuscript and Supplementary Material. It separates frozen source code, stored checkpoints, audit/provenance material, and publication documents.

## Important scope statement
This v1 repository contains the raw artifacts that were available and verified during package assembly. It is **not yet the complete public release** for all 30 primary PG/GF runs and all A1–A4 ablation runs. The currently verified raw checkpoint set is SAC-GF MS01. Missing run-level artifacts are listed in `metadata/MISSING_FOR_COMPLETE_RELEASE.csv` and must be added before this repository is described as a complete reproduction archive.

## Directory map
- `code/` — frozen MATLAB source currently available.
- `checkpoints/sac_gf_ms01/` — stored SAC-GF MS01 curriculum checkpoints (to be deposited as release/archive assets).
- `audit/` — SAC checkpoint forensic audit script.
- `results/` — machine-readable summary tables for the reported experiment.
- `metadata/` — inventory, environment/provenance notes, and completion manifest.
- `docs/` — manuscript and Supplementary Material for traceability.
- `figures/` — publication figures.
  
## Reproduction logic
1. Read `metadata/ENVIRONMENT.txt` and the frozen-protocol description in the Supplementary Material.
2. Inspect the frozen source in `code/` and the serialized checkpoints in the archived release.
3. Run `audit/SAC_P0_Audit_Checkpoint_v2.m` in MATLAB R2024b or a compatible release to inspect the stored SAC actor and deployment behavior.
4. Use `results/` to trace aggregate manuscript claims to run-level accounting once the missing primary/ablation artifacts are deposited.

## Publication workflow
Use this GitHub repository for readable/version-controlled code and metadata. After the missing-artifact manifest is cleared and the final package is audited, create tag `v1.0.0` and archive that tagged release in Zenodo. Cite the Zenodo DOI in the article's Data/Code Availability statement rather than citing only the moving GitHub branch.

## Integrity and limitations
No unavailable numerical values have been fabricated. A missing raw artifact is represented as missing rather than reconstructed from an aggregate manuscript value. The infrastructure-censored SAC-A1-MS05 run must remain explicitly censored in any completed release.
