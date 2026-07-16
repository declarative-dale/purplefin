"""Adapter used by the Purplefin Anaconda spoke to select a bootc source.

The graphical spoke owns its widgets; it calls ``resolve_source`` immediately
before the payload is committed, then assigns the returned value to Anaconda's
bootc source-image-reference property.  Keeping the policy in the shell helper
makes the security-critical mapping independently testable outside Anaconda.
"""

from __future__ import annotations

import os
import subprocess


HELPER = "/usr/libexec/purplefin-installer/select-image"


def detected_hardware() -> str:
    return subprocess.check_output([HELPER, "detect-hardware"], text=True).strip()


def available_presets() -> list[tuple[str, str]]:
    output = subprocess.check_output([HELPER, "list-presets"], text=True)
    return [tuple(line.rstrip("\n").split("\t", 1)) for line in output.splitlines()]


def resolve_source(preset: str, hardware: str | None = None) -> str:
    command = [HELPER, "resolve", preset]
    if hardware:
        command.append(hardware)
    return subprocess.check_output(command, text=True, env=os.environ.copy()).strip()
