#!/usr/bin/env python3
"""Generate the deterministic, privacy-safe DM-026 50 x 30 profile fixture."""

from __future__ import annotations

import argparse
import json
import uuid
from pathlib import Path


NAMESPACE = uuid.UUID("82fdbb25-bbdc-4f0d-92bf-45253f3871e0")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    profiles = []
    for profile_index in range(1, 51):
        actions = []
        for action_index in range(1, 31):
            actions.append(
                {
                    "id": str(uuid.uuid5(NAMESPACE, f"profile-{profile_index}-action-{action_index}")),
                    "label": f"Action {action_index:02d}",
                    "enabled": True,
                    "timeoutSeconds": 10,
                    "kind": {
                        "type": "openURL",
                        "payload": {
                            "url": f"https://example.invalid/profile-{profile_index:02d}/action-{action_index:02d}"
                        },
                    },
                }
            )
        profiles.append(
            {
                "id": str(uuid.uuid5(NAMESPACE, f"profile-{profile_index}")),
                "name": f"Performance Profile {profile_index:02d}",
                "createdAt": "2026-09-06T12:00:00Z",
                "updatedAt": "2026-09-06T12:00:00Z",
                "failurePolicy": "continue",
                "shortcut": None,
                "actions": actions,
            }
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(
            {"schemaVersion": 1, "revision": 1, "profiles": profiles},
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
