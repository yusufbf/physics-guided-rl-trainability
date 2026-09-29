# MATLAB figure reproduction

Open this directory in MATLAB R2024b and run `reproduce_figures_v14`. The script reads the portable CSVs in `../results/` and writes `output/Figure_01_audit.png` through `Figure_08_audit.png`. No Reinforcement Learning Toolbox is needed for **plotting**; the archived training scripts have separate requirements.

Figures 3 and 5–8 are derived from rules and audited result summaries. Figures 1, 2, and 4 are schematic audit renditions; the manuscript's embedded Figure 1 and 4 are the preferred publication diagrams. Figure 2 obstacle locations are illustrative. Figure 7(c) presents TD3/SAC clearance rows from the CSV and is not a pixel-identical reproduction of the manuscript's selected prose. The plotted behavior metrics use successful-episode means where route completion is required.

The MATLAB program was executed by the researcher on 29 September 2026 and the resulting eight PNGs were visually inspected. The copies in this Git tree should still be run from a fresh checkout as a release gate. Do not confuse successful figure rendering with re-execution of training or final-test rollouts.
