# Provenance and evidence boundary

This package was assembled on 29 September 2026 from the local `D:\RL-Physics` research archive and the read-only forensic audit ledger associated with manuscript V14. The included source files were SHA-256 checked against ledger hashes where available. The result CSVs are **derived summaries** of MAT outputs and validation records, not raw experimental data. Source file paths and local user information were removed from the portable CSVs; original-file SHA-256 values remain where available.

The audit verified the manuscript's principal Tables 6–10 counts and transformations against archived outputs. It did not rerun DDPG, TD3, or SAC training. Archived sources do not contain a saved self-hash from every actual execution. Some MATLAB objects and historical runtime details cannot be fully decoded from the current archive. A folder name, file timestamp, or matching script name alone is not a certification of execution identity.

Primary design: 3 algorithms × 2 formulations × 5 paired seed indices = 30 runs. The GF comparator was frozen after seeing PG screening MS01–MS03 and before PG MS04–MS05 outcomes. Jointly qualified pairs are a conditional subset and should not be used to estimate unconditional sample-efficiency gains.

Ablation design: 4 component removals × 3 algorithms × 3 selected seeds = 36 planned conditions. Thirty-five have completed outcomes and SAC-A1-MS05 is infrastructure-censored. A separate recovery did not exactly restore the original random state and is not counted as a clean replacement. One-at-a-time ablations use matched historical Full-PG controls; they do not identify all cross-component interactions or uniquely prove a physical mechanism.

The archived SAC source uses a tanh-bounded Gaussian mean plus the toolbox's outer tanh. Static inspection of the available R2024b source supports deterministic action magnitude ≤ `tanh(1)` per goal-frame component, making a deterministic `|u| ≥ 0.95` saturation criterion vacuous for SAC. This is an interpretation limit of the archived actor, not a new experiment or certification of all historical runtimes.

Manuscript Figure 1 and 4 are retained as editorial schematics. The MATLAB figure script in this repository makes simplified audit diagrams for those figures. The plot's Figure 7(c) lists secondary clearance data rather than recreating the manuscript's prose-style selection; compare numerical claims and denominators rather than pixel identity.
