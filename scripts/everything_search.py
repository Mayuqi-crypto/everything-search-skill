#!/usr/bin/env python3
"""
Search files and folders using Everything (es.exe).
Outputs results as plain text list or JSON.
"""

import sys
import os
import shutil
import subprocess
import argparse
import json
import csv
import io


def find_es_binary():
    # Check PATH first
    es_in_path = shutil.which("es") or shutil.which("es.exe")
    if es_in_path:
        return es_in_path

    # Check script-relative and user directories
    base_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(base_dir, "..", "bin", "es.exe"),
        os.path.expanduser(r"~/.local/bin/es.exe"),
        r"C:\Program Files\Everything\es.exe",
        r"C:\Program Files (x86)\Everything\es.exe",
    ]
    for c in candidates:
        if os.path.exists(c):
            return os.path.abspath(c)

    return None


def main():
    parser = argparse.ArgumentParser(description="Search files with Everything (es.exe)")
    parser.add_argument("query", help="Everything search query string")
    parser.add_argument("-p", "--path", help="Limit search to this folder")
    parser.add_argument("-n", "--limit", type=int, default=25, help="Max results (default: 25)")
    parser.add_argument("-t", "--type", choices=["all", "file", "dir", "folder"], default="all", help="Result type")
    parser.add_argument("-s", "--sort", choices=["default", "dm", "size", "name"], default="default", help="Sort order")
    parser.add_argument("--json", action="store_true", help="Output results as JSON")

    args = parser.parse_args()

    es_bin = find_es_binary()
    if not es_bin:
        sys.stderr.write("Error: es.exe not found. Make sure Everything is installed and es.exe is in PATH.\n")
        sys.exit(1)

    cmd = [es_bin]

    if args.limit > 0:
        cmd.extend(["-n", str(args.limit)])

    if args.path:
        abs_p = os.path.abspath(args.path)
        if os.path.exists(abs_p):
            cmd.extend(["-path", abs_p])

    if args.type in ("dir", "folder"):
        cmd.append("/ad")
    elif args.type == "file":
        cmd.append("/a-d")

    if args.sort == "dm":
        cmd.append("-sort-date-modified-descending")
    elif args.sort == "size":
        cmd.append("-sort-size-descending")
    elif args.sort == "name":
        cmd.append("-sort-name-ascending")

    if args.json:
        cmd.extend(["-csv", "-size", "-date-modified"])

    cmd.append(args.query)

    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace")
    except Exception as e:
        sys.stderr.write(f"Failed to execute es: {e}\n")
        sys.exit(1)

    if proc.returncode != 0 and proc.stderr:
        sys.stderr.write(f"es error: {proc.stderr}\n")
        sys.exit(proc.returncode)

    stdout = proc.stdout.strip()
    if not stdout:
        if args.json:
            print("[]")
        return

    if args.json:
        reader = csv.DictReader(io.StringIO(stdout))
        results = []
        for row in reader:
            results.append({
                "filename": row.get("Filename", ""),
                "size": row.get("Size", ""),
                "date_modified": row.get("Date Modified", "")
            })
        print(json.dumps(results, indent=2, ensure_ascii=False))
    else:
        print(stdout)


if __name__ == "__main__":
    main()
