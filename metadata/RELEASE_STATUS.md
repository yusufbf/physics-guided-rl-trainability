# Release status — V16 evidence candidate

Private review branch `v16-evidence-release-candidate`. This branch contains the 112 audited raw-result MAT files, 47 selected Stage-10 pass checkpoints, an extracted final-test scenario bank, eight representative validation-bank classes, per-run bank mappings, and integrity manifests. Git blob SHA-1 values matched the local files at upload; a recursive tree check found all 177 initially staged files with no mismatches. Independent regeneration from archived sampling rules, saved configurations, and seeds exactly matched 21,172 recorded final/validation scenarios across all 112 raw-result files. A separate local staging copy passed both Python integrity verifiers. MATLAB R2024b generated Figures 2, 3, and 5–8 in PNG/TIF 600 dpi and vector PDF/EPS from that copy; Figure 7 was visually checked for toolbar artifacts.

The following still need explicit closure before this branch becomes the article's public archival record:

1. Run both integrity verifiers and the MATLAB figure reproducer from an independent network checkout of this branch, and compare all generated figures with the manuscript artwork. Figures 1 and 4 are embedded publication diagrams. The local staging-copy test is complete.
2. Review redistribution rights, author approval, license, citation metadata, and version label. Preserve the historical missing executed-source self-hashes and censored SAC-A1-MS05 disclosure.
3. Make the exact tested release publicly accessible, create a stable archival identifier or version-pinned public citation, and verify that an unauthenticated reader can retrieve the complete raw archive.

No public-data availability claim or DOI should be inserted into the manuscript before item 3 is verified. End-to-end training retraining is not claimed by this archive.

