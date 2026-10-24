#!/usr/bin/env python3
"""
Codeforces Accepted Solution Watcher & Auto-Push Script (Python Version).

Monitors repository directory for saved solution files (.cpp, .py, .java, etc.).
When an Accepted solution file is saved/created, stages the file, commits it with
a formatted commit message, and pushes to GitHub main branch.
"""

import sys
import os
import time
import subprocess
import re
from pathlib import Path

WATCH_EXTENSIONS = {".cpp", ".cc", ".cxx", ".c", ".py", ".java", ".rs", ".go"}
DEBOUNCE_SECONDS = 2.0
NEGATIVE_PATTERNS = re.compile(r"(wrong\s*answer|\bwa\b|time\s*limit\s*exceeded|\btle\b|runtime\s*error|\bre\b|compilation\s*error|\bdraft\b|\btesting\b)", re.IGNORECASE)
POSITIVE_PATTERNS = re.compile(r"(verdict:\s*accepted|\bstatus:\s*accepted|\baccepted\b|\bverdict\s*:\s*ac\b)", re.IGNORECASE)

def is_accepted_file(file_path: Path, mode: str = "Smart") -> bool:
    if mode == "All":
        return True

    name = file_path.name.lower()
    parent = file_path.parent.name.lower()

    if "accepted" in name or "_ac" in name or "accepted" in parent:
        return True

    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            lines = [f.readline() for _ in range(30)]
            content = "".join(lines)

            if NEGATIVE_PATTERNS.search(content):
                return False

            if POSITIVE_PATTERNS.search(content):
                return True

            if mode == "Smart" and len(lines) >= 3:
                return True
    except Exception:
        return False

    return False

def get_problem_title(file_path: Path) -> str:
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            for _ in range(15):
                line = f.readline()
                match = re.search(r"problem\s*(?:name|title|code)?\s*:\s*(.+)", line, re.IGNORECASE)
                if match:
                    cleaned = match.group(1).strip(" *#/-\t\r\n")
                    if cleaned:
                        return cleaned
    except Exception:
        pass
    return file_path.stem

def run_git(args: list[str]) -> tuple[int, str]:
    res = subprocess.run(["git"] + args, capture_output=True, text=True, check=False)
    output = (res.stdout + res.stderr).strip()
    return res.returncode, output

def commit_and_push(file_path: Path, remote: str = "origin", branch: str = "main"):
    rel_path = file_path.name
    try:
        rel_path = file_path.relative_to(Path.cwd())
    except ValueError:
        pass

    problem = get_problem_title(file_path)
    now_str = time.strftime("%Y-%m-%d %H:%M:%S")
    commit_msg = f"Solve Codeforces: {problem} [Accepted] - {now_str}"

    print(f"\n[{time.strftime('%H:%M:%S')}] Detected Accepted solution: {rel_path}")
    print(f"  -> Staging: {rel_path}")

    code, out = run_git(["add", "--", str(file_path)])
    if code != 0:
        print(f"  [!] git add failed: {out}")
        return

    code, status_out = run_git(["status", "--porcelain", str(file_path)])
    if not status_out:
        print(f"  [*] No new changes to commit for {rel_path}.")
        return

    print(f"  -> Committing: \"{commit_msg}\"")
    code, out = run_git(["commit", "-m", commit_msg])
    if code != 0:
        print(f"  [!] git commit failed: {out}")
        return

    print(f"  -> Pushing to {remote}/{branch}...")
    code, out = run_git(["push", remote, branch])
    if code == 0:
        print(f"  [✓] Successfully pushed to {remote}/{branch}!")
    else:
        print(f"  [!] Push notice: git push returned an error.")
        print(f"      Details: {out}")
        print(f"      Tip: Verify your GitHub remote with: git remote set-url {remote} https://github.com/<user>/<repo>.git")
        print(f"      (Your commit has been safely recorded locally in Git)")

def watch(watch_dir: Path, branch: str = "main", remote: str = "origin", mode: str = "Smart"):
    print("=" * 60)
    print("  Codeforces Auto-Commit & Push Watcher (Python)")
    print("=" * 60)
    print(f" Directory      : {watch_dir.resolve()}")
    print(f" Target branch  : {branch}")
    print(f" Remote         : {remote}")
    print(f" Mode           : {mode}")
    print(f" Active Status  : Monitoring for saves (Press Ctrl+C to stop)...")
    print("=" * 60 + "\n")

    last_seen_mtimes: dict[str, float] = {}
    last_handled_time: dict[str, float] = {}

    # Initialize snapshot
    for path in watch_dir.rglob("*"):
        if path.is_file() and path.suffix.lower() in WATCH_EXTENSIONS:
            if ".git" not in path.parts and ".cph" not in path.parts and ".vscode" not in path.parts:
                try:
                    last_seen_mtimes[str(path.resolve())] = path.stat().st_mtime
                except OSError:
                    pass

    try:
        while True:
            time.sleep(1)
            current_files = []
            for path in watch_dir.rglob("*"):
                if path.is_file() and path.suffix.lower() in WATCH_EXTENSIONS:
                    if ".git" in path.parts or ".cph" in path.parts or ".vscode" in path.parts:
                        continue
                    current_files.append(path)

            for path in current_files:
                resolved_str = str(path.resolve())
                try:
                    mtime = path.stat().st_mtime
                except OSError:
                    continue

                prev_mtime = last_seen_mtimes.get(resolved_str)
                if prev_mtime is None or mtime > prev_mtime:
                    last_seen_mtimes[resolved_str] = mtime
                    now = time.time()
                    last_done = last_handled_time.get(resolved_str, 0)
                    if (now - last_done) >= DEBOUNCE_SECONDS:
                        last_handled_time[resolved_str] = now
                        time.sleep(0.3)
                        if is_accepted_file(path, mode):
                            commit_and_push(path, remote=remote, branch=branch)

    except KeyboardInterrupt:
        print("\nWatcher stopped.")

if __name__ == "__main__":
    mode_arg = "Smart"
    branch_arg = "main"
    remote_arg = "origin"

    if "--all" in sys.argv:
        mode_arg = "All"
    if "--accepted" in sys.argv:
        mode_arg = "Accepted"

    watch(Path.cwd(), branch=branch_arg, remote=remote_arg, mode=mode_arg)
