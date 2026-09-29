# Data dictionary and denominators

## `results/primary_run_ledger.csv`

One row per primary training run (30 rows). `algorithm` is DDPG, TD3, or SAC; `arm` is PG or GF; `seed` is the paired MS index. `highest_mastered == 10` denotes Stage-10 qualification. `interactions` counts consumed environment interactions, **not** a valid cost-to-mastery for failed runs. `final_test_performed`, `test_n`, and `test_success_pct` describe actual post-qualification evaluation; blank success means no final test. SHA-256 columns identify archived MAT or canonical scenario/configuration structures where recorded. `scenario_bank_sha256` is a canonical serialized-structure hash, not a raw MAT byte hash.

## `results/paired_primary_recomputed.csv`

Seven rows for seed pairs in which **both** PG and GF qualified. `PG` and `GF` are interactions to mastery. `reduction_pct = 100 × (GF − PG) / GF`; positive means PG required fewer interactions. `PG_success` and `GF_success` are nominal final-test success percentages on a shared 100-scenario bank. This table must not be interpreted as covering the eight failed primary runs.

## `results/ablation_run_matrix_36.csv`

One row per planned ablation condition. `arm` is A1 (remove braking-aware desired speed), A2 (remove dynamic warning), A3 (remove terminal relaxation), or A4 (remove stage-specific horizon). `status` distinguishes `complete mastered`, `mastery failed`, and the infrastructure-censored SAC-A1-MS05 condition. Only completed outcomes enter clean completion rates. A failed mastery run is still a completed experimental outcome; the censored run is not.

## `results/paired_ablation_recomputed.csv`

Twenty-five rows where an ablation policy and its matched historical Full-PG control both mastered. `FullPG` and `Ai` are interaction counts. `delta_pct = 100 × (Ai − FullPG) / FullPG`; positive means component removal cost more interactions. The median signed effect and the median of absolute effects answer different questions. Failed and censored conditions have no cost-to-mastery value.

## `results/figure7_metrics.csv`

Behavioral summaries from nominal final tests. `_all` columns average over all scenarios where the metric is defined. `_success` columns average only successful episodes; use these for route-completion dependent behavior in Figure 7. A policy's 100 scenarios are repeated evaluations of one trained policy, **not 100 independent training replicates**. SAC deterministic saturation at the frozen 0.95 threshold is structurally zero under the archived actor.
