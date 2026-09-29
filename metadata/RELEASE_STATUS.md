# Release status

As of 29 September 2026: **PRIVATE / AUDITED PARTIAL RELEASE**. The repository now includes archived text source for 30 primary and 36 planned ablation conditions, portable run-level summary ledgers, paired calculations, a verification program, and a MATLAB figure reproducer. This improves inspection and figure reproduction, but it does not make the original experiments fully rerunnable from Git alone.

The following gates remain open before a complete public `v1.0.0` and Zenodo deposit:

1. Select and deposit the raw MAT training statistics, final-test arrays, and representative checkpoints with per-file SHA-256 and a clear external-asset mapping. Large binary data should be a release/archival asset rather than an ordinary Git blob.
2. Deposit or precisely regenerate the frozen scenario banks and their code, including target and obstacle distributions and random-stream handling. Check canonical and raw hashes separately.
3. Verify the full environment manifest for every run where possible; the current R2024b source audit is not proof of every historical training environment.
4. Run the portable integrity check and MATLAB figure script from a clean checkout; visually compare output with manuscript V14. Perform at least one documented end-to-end rerun if the release is to claim executable training reproduction.
5. Resolve or transparently bound the SAC actor discrepancy and the infrastructure-censored run in the manuscript and archive. Do not silently promote recovery output to a clean run.
6. Audit redistribution, licensing, documentation, and the final DOI metadata; then tag the exact tested commit, archive that tag, and update the manuscript availability statement.

The present Git commit may be cited for **source inspection, aggregate-accounting checks, and figure reconstruction** only. It is not a complete original-output archive or a verified one-command training reproduction.
