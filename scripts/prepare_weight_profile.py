#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path


def link_or_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.link(source, destination)
    except OSError:
        shutil.copy2(source, destination)


def stage_directory(source: Path, destination: Path) -> tuple[int, int]:
    file_count = 0
    total_bytes = 0
    for path in source.rglob("*"):
        relative = path.relative_to(source)
        target = destination / relative
        if path.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        elif path.is_file():
            link_or_copy(path, target)
            file_count += 1
            total_bytes += path.stat().st_size
    return file_count, total_bytes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", default="common")
    parser.add_argument("--source", type=Path, default=Path("PCLA/pcla_agents"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--registry",
        type=Path,
        default=Path("pcla_wrapper/agent_profiles.json"),
    )
    args = parser.parse_args()

    profiles = json.loads(args.registry.read_text(encoding="utf-8"))
    if args.profile not in profiles:
        parser.error(f"unknown profile: {args.profile}")
    profile = profiles[args.profile]

    output = args.output.resolve()
    if output.exists():
        if any(output.iterdir()):
            parser.error(f"output directory must be empty: {output}")
    else:
        output.mkdir(parents=True)

    total_files = 0
    total_bytes = 0
    for directory_name in profile["weight_directories"]:
        source = (args.source / directory_name).resolve()
        if not source.is_dir():
            parser.error(f"weight directory not found: {source}")
        file_count, byte_count = stage_directory(source, output / directory_name)
        total_files += file_count
        total_bytes += byte_count

    missing = []
    for agent_paths in profile["agents"].values():
        for relative_path in agent_paths:
            if not (output / relative_path).is_file():
                missing.append(relative_path)
    if missing:
        parser.error("missing required weights: " + ", ".join(sorted(set(missing))))

    registry_sha256 = hashlib.sha256(args.registry.read_bytes()).hexdigest()
    manifest = {
        "profile": args.profile,
        "weight_directories": profile["weight_directories"],
        "file_count": total_files,
        "total_bytes": total_bytes,
        "registry_sha256": registry_sha256,
    }
    (output / "pcla-weight-profile.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(manifest, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
