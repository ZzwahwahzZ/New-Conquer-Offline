#!/usr/bin/env python3
"""Run verbose Godot imports, preserve complete logs, and quarantine failing assets safely."""
from pathlib import Path
from queue import Queue, Empty
from threading import Thread
import argparse
import re
import shutil
import subprocess
import sys
import time

ASSET_RE = re.compile(r"""res://([^\s"'<>]+\.(?:glb|gltf|png|jpe?g))""", re.IGNORECASE)
ERROR_RE = re.compile(r"(?:ERROR:|Failed to load|Failed loading resource)", re.IGNORECASE)


def safe_project_asset(root: Path, relative: str):
    source = (root / relative).resolve()
    if root not in source.parents or not source.is_file():
        return None
    return source


def error_candidates(lines):
    found = []
    for index, line in enumerate(lines):
        if ERROR_RE.search(line):
            # Prefer a path on the error line, then the closest preceding path.
            context = list(reversed(lines[max(0, index - 30): index + 1]))
            for candidate_line in context:
                for path in ASSET_RE.findall(candidate_line):
                    if path not in found:
                        found.append(path)
    return found


def quarantine_asset(root: Path, quarantine: Path, relative: str, attempt: int) -> bool:
    source = safe_project_asset(root, relative)
    if source is None:
        return False
    destination = quarantine / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        destination = destination.with_name(destination.stem + f".attempt{attempt}" + destination.suffix)
    shutil.move(str(source), str(destination))
    print(f"QUARANTINED_FAILED_ASSET: res://{relative} -> {destination}", flush=True)
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--max-retries", type=int, default=12)
    parser.add_argument("--quarantine", type=Path, default=Path("/tmp/godot-asset-quarantine"))
    parser.add_argument("--log", type=Path, default=Path("reports/godot_import_guard.log"))
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command and args.command[0] == "--" else args.command
    if not command:
        parser.error("Provide the Godot command after --")

    root = Path.cwd().resolve()
    quarantine = args.quarantine.resolve()
    log_path = args.log if args.log.is_absolute() else root / args.log
    log_path.parent.mkdir(parents=True, exist_ok=True)
    quarantine.mkdir(parents=True, exist_ok=True)

    with log_path.open("w", encoding="utf-8", errors="replace") as log:
        log.write("Godot import guard log; stdout and stderr are captured separately.\n")
        log.flush()

        def emit(stream_name, line):
            log.write(f"[{stream_name}] {line}")
            log.flush()
            target = sys.stderr if stream_name == "stderr" else sys.stdout
            target.write(line)
            target.flush()

        for attempt in range(args.max_retries + 1):
            header = f"\n===== IMPORT_ATTEMPT={attempt + 1} COMMAND={' '.join(command)} =====\n"
            log.write(header)
            log.flush()
            print(header, end="", flush=True)
            process = subprocess.Popen(
                command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                text=True, encoding="utf-8", errors="replace", bufsize=1
            )
            events = Queue()
            def pump(pipe, name):
                try:
                    for line in pipe:
                        events.put((name, line))
                finally:
                    events.put((name, None))
            Thread(target=pump, args=(process.stdout, "stdout"), daemon=True).start()
            Thread(target=pump, args=(process.stderr, "stderr"), daemon=True).start()

            captured = []
            recent_assets = []
            ended = set()
            deadline = time.monotonic() + args.timeout
            timed_out = False
            while len(ended) < 2:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    timed_out = process.poll() is None
                    break
                try:
                    name, line = events.get(timeout=min(0.25, remaining))
                except Empty:
                    continue
                if line is None:
                    ended.add(name)
                    continue
                emit(name, line)
                captured.append(line)
                matches = ASSET_RE.findall(line)
                if matches:
                    recent_assets.extend(matches)

            if timed_out:
                emit("guard", f"IMPORT_TIMEOUT after {args.timeout}s\n")
                process.kill()
                process.wait()
                candidates = list(dict.fromkeys(recent_assets[-30:]))
                if not candidates:
                    emit("guard", "ERROR: timeout but no active GLB/image path was identifiable; refusing arbitrary quarantine.\n")
                    return 124
                candidate = candidates[-1]
                if not quarantine_asset(root, quarantine, candidate, attempt + 1):
                    emit("guard", f"ERROR: timeout candidate is not a removable project asset: {candidate}\n")
                    return 124
            else:
                code = process.wait()
                if code == 0:
                    emit("guard", "GODOT_IMPORT_GUARD_PASS\n")
                    return 0

                emit("guard", f"GODOT_NONZERO_EXIT: returncode={code}\n")
                candidates = error_candidates(captured)
                quarantined = False
                for candidate in candidates:
                    if quarantine_asset(root, quarantine, candidate, attempt + 1):
                        quarantined = True
                        break
                if not quarantined:
                    emit("guard", "ERROR: Godot exited non-zero, but no safe GLB/image path was tied to an error; refusing arbitrary quarantine.\n")
                    return code

            if attempt == args.max_retries:
                emit("guard", "ERROR: retry limit exhausted.\n")
                return 124

    return 124


if __name__ == "__main__":
    sys.exit(main())
