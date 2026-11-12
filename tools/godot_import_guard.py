#!/usr/bin/env python3
"""Run verbose Godot import with a per-attempt timeout and quarantine the last asset."""
from pathlib import Path
from queue import Queue, Empty
from threading import Thread
import argparse
import re
import shutil
import subprocess
import sys
import time

ASSET_RE = re.compile(r"""res://([^\\s"'<>]+\\.(?:glb|gltf|png|jpe?g))""", re.IGNORECASE)

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--max-retries", type=int, default=12)
    parser.add_argument("--quarantine", type=Path, default=Path("/tmp/godot-asset-quarantine"))
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command and args.command[0] == "--" else args.command
    if not command:
        parser.error("Provide the Godot command after --")
    root = Path.cwd().resolve()
    quarantine = args.quarantine.resolve()
    quarantine.mkdir(parents=True, exist_ok=True)

    for attempt in range(args.max_retries + 1):
        print(f"IMPORT_ATTEMPT={attempt + 1} COMMAND={' '.join(command)}", flush=True)
        process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, bufsize=1)
        lines = Queue()
        def pump():
            for line in process.stdout:
                lines.put(line)
            lines.put(None)
        Thread(target=pump, daemon=True).start()
        deadline = time.monotonic() + args.timeout
        recent = []
        last_asset = None
        stream_closed = False
        while time.monotonic() < deadline and not stream_closed:
            try:
                line = lines.get(timeout=min(0.25, max(0.01, deadline - time.monotonic())))
            except Empty:
                if process.poll() is not None:
                    break
                continue
            if line is None:
                stream_closed = True
                break
            print(line, end="", flush=True)
            recent.append(line)
            if len(recent) > 300:
                recent.pop(0)
            matches = ASSET_RE.findall(line)
            if matches:
                last_asset = matches[-1]

        if process.poll() is not None:
            code = process.wait()
            if code == 0:
                print("GODOT_IMPORT_GUARD_PASS", flush=True)
            return code
        if time.monotonic() < deadline and stream_closed:
            code = process.wait()
            if code == 0:
                print("GODOT_IMPORT_GUARD_PASS", flush=True)
            return code

        print(f"IMPORT_TIMEOUT after {args.timeout}s", flush=True)
        process.kill()
        process.wait()
        if not last_asset:
            print("ERROR: timed out but no active GLB/image path was identifiable; refusing to remove an arbitrary asset.", flush=True)
            return 124
        source = (root / last_asset).resolve()
        if root not in source.parents or not source.is_file():
            print(f"ERROR: candidate asset is not a removable project file: {last_asset}", flush=True)
            return 124
        destination = quarantine / last_asset
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            destination = destination.with_name(destination.stem + f".attempt{attempt + 1}" + destination.suffix)
        shutil.move(str(source), str(destination))
        print(f"QUARANTINED_HANGING_ASSET: res://{last_asset} -> {destination}", flush=True)
        if attempt == args.max_retries:
            print("ERROR: retry limit exhausted.", flush=True)
            return 124

    return 124

if __name__ == "__main__":
    sys.exit(main())
