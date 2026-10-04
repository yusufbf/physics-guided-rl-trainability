# Release status — V16 evidence candidate

The V16 evidence archive was merged to the now-public `main` branch via PR #2. It contains the 112 audited raw-result MAT files, 47 selected Stage-10 pass checkpoints, an extracted final-test scenario bank, eight representative validation-bank classes, per-run bank mappings, and integrity manifests. Git blob SHA-1 values matched the local files at upload; the recursive tree check found all 180 staged `raw_evidence/` files with no mismatches. Independent regeneration from archived sampling rules, saved configurations, and seeds exactly matched 21,172 recorded final/validation scenarios across all 112 raw-result files. A separate local staging copy passed both Python integrity verifiers. MATLAB R2024b generated Figures 2, 3, and 5–8 in PNG/TIF 600 dpi and vector PDF/EPS from that copy; Figure 7 was visually checked for toolbar artifacts.

The following remain before a Zenodo DOI can be cited:

1. Run both integrity verifiers and the MATLAB figure reproducer from an independent network checkout of `main`, and compare all generated figures with the manuscript artwork. Figures 1 and 4 are embedded publication diagrams. The local staging-copy test is complete.
2. Record the authors' chosen license and version label. Preserve the historical missing executed-source self-hashes and censored SAC-A1-MS05 disclosure.
3. Enable the GitHub repository in the authors' Zenodo account, create a GitHub release from the exact reviewed commit, and verify the resulting Zenodo record and DOI. Anonymous access to the GitHub repository and `raw_evidence/raw_mat/` was verified on 4 October 2026.

The article may cite an exact public GitHub commit for the present data/code archive; do not claim a Zenodo DOI until its record exists and is verified. End-to-end training retraining is not claimed by this archive.

