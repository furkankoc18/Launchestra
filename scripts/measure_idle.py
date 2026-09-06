#!/usr/bin/env python3
"""Launch a Release app with a fixture and sample idle CPU/RSS."""

from __future__ import annotations

import argparse
import json
import os
import platform
import statistics
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path


def sysctl(name: str) -> str:
    return subprocess.check_output(["sysctl", "-n", name], text=True).strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--executable", required=True, type=Path)
    parser.add_argument("--profile-directory", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--duration", type=int, default=300)
    parser.add_argument("--interval", type=float, default=5.0)
    args = parser.parse_args()

    if not args.executable.is_file():
        raise SystemExit(f"Executable does not exist: {args.executable}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    environment["DESKMODE_PROFILE_DIRECTORY"] = str(args.profile_directory)
    started_at = datetime.now(timezone.utc).isoformat()
    process = subprocess.Popen(
        [str(args.executable), "--performance-idle-smoke"],
        env=environment,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    samples: list[dict[str, float]] = []
    start = time.monotonic()
    try:
        while True:
            elapsed = time.monotonic() - start
            if elapsed >= args.duration:
                break
            if process.poll() is not None:
                raise RuntimeError(f"Launchestra exited early with code {process.returncode}")
            output = subprocess.check_output(
                ["ps", "-p", str(process.pid), "-o", "%cpu=", "-o", "rss="], text=True
            ).strip()
            cpu_text, rss_text = output.split()
            samples.append(
                {
                    "elapsedSeconds": round(elapsed, 3),
                    "cpuPercent": float(cpu_text),
                    "rssMiB": round(int(rss_text) / 1024, 3),
                }
            )
            time.sleep(min(args.interval, max(0.0, args.duration - (time.monotonic() - start))))
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()

    cpu = [item["cpuPercent"] for item in samples]
    rss = [item["rssMiB"] for item in samples]
    report = {
        "startedAtUTC": started_at,
        "durationSeconds": args.duration,
        "intervalSeconds": args.interval,
        "sampleCount": len(samples),
        "fixture": {"profileCount": 50, "actionsPerProfile": 30},
        "device": {
            "model": sysctl("hw.model"),
            "architecture": platform.machine(),
            "macOS": platform.mac_ver()[0],
            "build": platform.version(),
        },
        "summary": {
            "averageCPUPercent": round(statistics.fmean(cpu), 3),
            "maximumCPUPercent": max(cpu),
            "averageRSSMiB": round(statistics.fmean(rss), 3),
            "maximumRSSMiB": max(rss),
        },
        "samples": samples,
    }
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
