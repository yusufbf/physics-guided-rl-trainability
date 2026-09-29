"""Check source hashes and result accounting without MATLAB or raw MAT files."""
from __future__ import annotations

import csv
import hashlib
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def read(path: str) -> list[dict[str, str]]:
    with (ROOT / path).open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


sources = read("metadata/source_manifest.csv")
check(len(sources) == 66, "Expected 66 archived source scripts")
for item in sources:
    path = ROOT / item["repository_path"]
    check(path.is_file(), f"Missing {path}")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    check(digest == item["sha256"], f"SHA-256 mismatch: {path}")

primary = read("results/primary_run_ledger.csv")
check(len(primary) == 30, "Expected 30 primary run rows")
expected = {
    ("DDPG", "PG"): 5, ("DDPG", "GF"): 1,
    ("TD3", "PG"): 5, ("TD3", "GF"): 4,
    ("SAC", "PG"): 3, ("SAC", "GF"): 4,
}
for (algorithm, arm), n in expected.items():
    rows = [r for r in primary if r["algorithm"] == algorithm and r["arm"] == arm]
    check(len(rows) == 5, f"Expected five primary seeds for {algorithm} {arm}")
    check(sum(int(r["highest_mastered"]) == 10 for r in rows) == n,
          f"Mastery mismatch: {algorithm} {arm}")

pairs = read("results/paired_primary_recomputed.csv")
check(len(pairs) == 7, "Expected seven jointly qualified primary pairs")
for row in pairs:
    pg, gf = int(row["PG"]), int(row["GF"])
    reduction = 100 * (gf - pg) / gf
    check(abs(reduction - float(row["reduction_pct"])) < 1e-8,
          f"Reduction mismatch: {row['algorithm']} MS{row['seed']}")
check(sum(float(r["reduction_pct"]) > 0 for r in pairs) == 6,
      "Expected six positive PG savings")
median = statistics.median(float(r["reduction_pct"]) for r in pairs)
check(abs(median - 27.992159522627166) < 1e-8, "Primary median mismatch")

ablations = read("results/ablation_run_matrix_36.csv")
check(len(ablations) == 36, "Expected 36 planned ablation rows")
censored = [r for r in ablations if "censor" in r["status"].lower()]
check(len(censored) == 1 and censored[0]["algorithm"] == "SAC"
      and censored[0]["arm"] == "A1" and censored[0]["seed"] == "5",
      "Censoring mismatch")
check(sum(r["highest_mastered"] == "10" for r in ablations) == 25,
      "Expected 25 mastered ablation outcomes")
for arm, n in {"A1": 6, "A2": 9, "A3": 3, "A4": 7}.items():
    check(sum(r["arm"] == arm and r["highest_mastered"] == "10"
              for r in ablations) == n, f"Ablation mastery mismatch: {arm}")

paired_ablations = read("results/paired_ablation_recomputed.csv")
check(len(paired_ablations) == 25, "Expected 25 paired-mastered ablations")
for row in paired_ablations:
    full, removed = int(row["FullPG"]), int(row["Ai"])
    check(abs(100 * (removed - full) / full - float(row["delta_pct"])) < 1e-8,
          f"Ablation cost mismatch: {row['algorithm']} {row['ablation']} MS{row['seed']}")

print("PASS: 66 source hashes; 30 primary runs; 7 pairs; 36 ablation slots")
print("PASS: 35 completed ablations + 1 censored; 25 paired-mastered comparisons")
print(f"PASS: 6/7 positive PG interaction reductions; median {median:.2f}%")
