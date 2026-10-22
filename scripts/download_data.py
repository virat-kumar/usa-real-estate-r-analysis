#!/usr/bin/env python3
"""Use official KaggleHub ONLY for Kaggle dataset version 25."""
import csv
import hashlib
import sys
from pathlib import Path
import kagglehub

DATASET = "ahmedshahriarsakib/usa-real-estate-dataset/versions/25"
NAME = "realtor-data.zip.csv"
SHA256 = "2678a7d0a1054861464d0dbdf938c133ffd3e5c5f22c8065255bab87e9af0de4"
REQUIRED = {"price", "bed", "bath", "house_size", "acre_lot", "city", "state", "zip_code", "prev_sold_date"}

def verify(path):
    if not path.is_file():
        raise RuntimeError("Kaggle dataset file not found: " + str(path))
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != SHA256:
        raise RuntimeError("Official version-25 dataset checksum mismatch: " + digest.hexdigest())
    with path.open("r", encoding="utf-8", newline="") as f:
        columns = set(next(csv.reader(f)))
    if not REQUIRED.issubset(columns):
        raise RuntimeError("Unexpected CSV columns: " + str(REQUIRED - columns))
    print("Verified official Kaggle version 25:", path)
    print("SHA-256:", digest.hexdigest())

def main():
    root = Path(__file__).resolve().parents[1]
    dest = root / "data" / "raw"
    dest.mkdir(parents=True, exist_ok=True)
    csv_path = dest / NAME
    if not csv_path.exists():
        print("Downloading directly from official Kaggle with KaggleHub...")
        kagglehub.dataset_download(DATASET, output_dir=str(dest))
    else:
        print("Found local original dataset; verifying before reuse.")
    verify(csv_path)

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("ERROR:", exc, file=sys.stderr)
        sys.exit(1)

