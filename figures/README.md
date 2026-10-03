# MATLAB figure reconstruction

In MATLAB R2024b, open this directory and run `reproduce_figures_v14`. The script reads the audited CSVs in `../results/` and exports Figures **2, 3, 5, 6, 7, and 8** to `output/` as PNG and TIF at 600 dpi plus vector PDF and EPS. Figures **1 and 4 are intentionally not generated**: use the diagrams embedded in the manuscript, which are the publication artwork.

This is reconstruction from archived formulas and summary data, not training or policy re-evaluation. Figure 2 uses illustrative obstacle geometry, not a frozen evaluation scenario. Figure 7(c) is a descriptive text layout and need not be pixel-identical to the manuscript image. The script hides axes toolbar icons before export. The raw MAT and frozen banks are in `../raw_evidence/` for audit of the underlying reported results.

The script was run from a separate staged copy in MATLAB R2024b on 4 October 2026. All six expected figure numbers produced all four formats, with 600-dpi PNG/TIF metadata; Figure 7 was visually inspected for toolbar artifacts. This is a staging-copy check, not a network clone of the eventual public version.

