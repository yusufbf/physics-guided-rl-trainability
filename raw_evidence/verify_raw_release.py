"""Verify staged raw evidence and the one-to-one run accounting."""
import csv
import hashlib
import json
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parent

def load_csv(name):
    with (root / name).open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream))

raw = load_csv("raw_mat_manifest.csv")
checkpoints = load_csv("checkpoint_manifest.csv")
assert Counter(r["kind"] for r in raw) == {"training_stats": 65, "final_test": 47}
assert len(checkpoints) == 47
assert len({r["relative_path"] for r in raw + checkpoints}) == 159
for row in raw + checkpoints:
    file = root / row["relative_path"]
    assert file.is_file(), row["relative_path"]
    assert file.stat().st_size == int(row["bytes"]), row["relative_path"]
    digest = hashlib.sha256(file.read_bytes()).hexdigest()
    assert digest == row["sha256"], row["relative_path"]
    if row in raw:
        assert digest == row["ledger_sha256"], row["relative_path"]

final_banks = load_csv("scenario_bank/bank_verification.csv")
validation_banks = load_csv("scenario_bank/validation_bank_verification.csv")
assert len(final_banks) == 47 and all(
    r["scenario_count"] == "100" and r["equals_reference"] == "1"
    for r in final_banks
)
assert len(validation_banks) == 65 and all(r["stage_count"] == "10" for r in validation_banks)
assert len({r["equivalence_class"] for r in validation_banks}) == 8
regenerated = load_csv("scenario_bank/independent_regeneration.csv")
assert len(regenerated) == 112
assert all(r["exact_match"] == "1" and r["matching_scenarios"] == r["total_scenarios"]
           for r in regenerated)
assert sum(int(r["total_scenarios"]) for r in regenerated) == 21172
assert (root / "scenario_bank/final10Scenarios.mat").is_file()
for i in range(1, 9):
    assert (root / f"scenario_bank/validation_bank_class_{i:02d}.mat").is_file()
print(json.dumps({"raw_mat": len(raw), "checkpoints": len(checkpoints),
                  "final_bank_rows": len(final_banks),
                  "validation_bank_rows": len(validation_banks),
                  "validation_bank_classes": 8, "regenerated_scenarios": 21172,
                  "result": "PASS"}))
