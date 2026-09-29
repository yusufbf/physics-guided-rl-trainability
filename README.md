# Physics-guided RL trainability: reproducibility companion

This private repository accompanies **“Physics-Guided Task Formulation as a Trainability Prior for Reinforcement Learning in Autonomous Motion Planning”** (manuscript V14, 28 September 2026). It is an **audited partial release**, not yet a complete archive from which every historical training and final-test result can be rerun exactly.

## What is included

- `code/primary/`: 30 archived MATLAB source scripts for the three algorithms × two formulations × five seeds. Source hashes are in `metadata/source_manifest.csv`. A matching source file is **not proof of the exact bytes executed historically**, because runtime self-hashes were not saved.
- `code/ablation/`: 36 planned script variants (A1–A4 on MS01, MS03, and MS05). One SAC-A1-MS05 outcome was infrastructure-censored; its source is included, but it is **not** a 36th clean completed result.
- `results/`: audited, portable run-level summaries and derived paired comparisons. These CSVs were reconstructed from archived outputs; they are not replacements for raw MAT files.
- `figures/reproduce_figures_v14.m`: MATLAB script producing audit versions of Figures 1–8 from the CSVs. Figures 1, 2, and 4 are schematics. Figure 7(c) uses a different descriptive layout from the manuscript image.
- `verify_package.py`: lightweight integrity and accounting checks; no MATLAB required.
- `metadata/`: provenance, environment, run coverage, and remaining release gaps.

## Check and reproduce what this package supports

```text
python verify_package.py
```

In MATLAB R2024b, open `figures/` and run:

```matlab
reproduce_figures_v14
```

The PNGs appear in `figures/output/`. This regenerates **figures from archived summary data**, not the experiment. Do not run the historical training scripts until their output paths, software dependencies, scenario generators, and compute budget have been reviewed in your environment.

## Scope of the reported result

The primary study contains **30 training runs**. Stage-10 qualification was DDPG PG/GF **5/5 vs 1/5**, TD3 **5/5 vs 4/5**, and SAC **3/5 vs 4/5**. Seven seed pairs qualified in both arms; PG used fewer interactions in six of them, with a median reduction of **27.99%** conditional on joint qualification. The selective ablation has **35 completed outcomes and one censored condition**, not 36 clean runs. The result applies to a simplified planar navigation testbed and the archived SAC actor configuration; it is not evidence of universal PG superiority or physical-robot safety.

The GF comparator was frozen **after PG MS01–MS03 screening and before PG MS04–MS05 outcomes**. Do not describe the entire study as prospectively frozen before observing any PG result. For the archived SAC actor, deterministic goal-frame actions are bounded by `tanh(1) ≈ 0.7616` per component because its mean and the toolbox action transform both use tanh. The 0.95 deterministic saturation threshold is therefore structurally unreachable for SAC; success remains the operative qualification signal.

## What remains unavailable here

The raw MAT results, policy checkpoints, exact scenario-bank generators/files, a complete historical runtime manifest, and a full end-to-end retraining verification are **not deposited in this Git tree**. See [`metadata/MISSING_FOR_COMPLETE_RELEASE.csv`](metadata/MISSING_FOR_COMPLETE_RELEASE.csv) and [`metadata/RELEASE_STATUS.md`](metadata/RELEASE_STATUS.md). The archived MAT files exist in the local research archive, but their full public-release selection, integrity packaging, and redistribution have not been completed. The earlier README's checkpoint and `docs/` directory map described planned deposits, not files actually present; this README reflects the current tree.

Do not call this package a complete reproduction archive, create a final `v1.0.0` tag, or cite a Zenodo DOI until those release gates are resolved. Cite the exact Git commit when using this interim package.

## Provenance

The numerical tables were audited against archived MAT outputs; the audit did **not** retrain agents. See [`metadata/PROVENANCE.md`](metadata/PROVENANCE.md), [`metadata/DATA_DICTIONARY.md`](metadata/DATA_DICTIONARY.md), and [`audit/SAC_P0_AUDIT_SUMMARY.md`](audit/SAC_P0_AUDIT_SUMMARY.md) for evidence boundaries.
