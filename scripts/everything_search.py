#!/usr/bin/env python3
"""
Dual-mode Everything Search for AI Agents:
1. HTTP REST API mode (Ideal for Sandboxes, Docker, WSL, remote agents)
2. Local CLI mode (es.exe via Win32 IPC for native desktop sessions)
"""

import sys
import os
import shutil
import subprocess
import argparse
import json
import csv
import io
import datetime
from urllib import request, parse, error

DEFAULT_HTTP_URL = os.environ.get("EVERYTHING_HTTP_URL", "http://127.0.0.1:8080")
HTTP_AUTH_USER = os.environ.get("EVERYTHING_HTTP_USER", "")
HTTP_AUTH_PASS = os.environ.get("EVERYTHING_HTTP_PASS", "")


def filetime_to_iso(ft):
    try:
        us = int(ft) // 10
        dt = datetime.datetime(1601, 1, 1) + datetime.timedelta(microseconds=us)
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        return str(ft)


def search_via_http(base_url, query, limit=25, path=None, item_type="all", sort="default"):
    # Build search query string
    q_parts = []
    if path:
        q_parts.append(f'path:"{path}"')
    if item_type in ("dir", "folder"):
        q_parts.append("/ad")
    elif item_type == "file":
        q_parts.append("/a-d")
    q_parts.append(query)

    full_query = " ".join(q_parts)

    params = {
        "search": full_query,
        "json": "1",
        "count": str(limit),
        "path_column": "1",
        "size_column": "1",
        "date_modified_column": "1"
    }

    # Sort handling
    if sort == "dm":
        params["sort"] = "date_modified"
        params["ascending"] = "0"
    elif sort == "size":
        params["sort"] = "size"
        params["ascending"] = "0"
    elif sort == "name":
        params["sort"] = "name"
        params["ascending"] = "1"

    url = f"{base_url.rstrip('/')}/?{parse.urlencode(params)}"

    req = request.Request(url)
    if HTTP_AUTH_USER and HTTP_AUTH_PASS:
        import base64
        auth = base64.b64encode(f"{HTTP_AUTH_USER}:{HTTP_AUTH_PASS}".encode()).decode()
        req.add_header("Authorization", f"Basic {auth}")

    with request.urlopen(req, timeout=3.0) as resp:
        if resp.status != 200:
            raise RuntimeError(f"HTTP {resp.status}")
        data = json.loads(resp.read().decode("utf-8", errors="replace"))

    results = []
    for item in data.get("results", []):
        folder = item.get("path", "")
        name = item.get("name", "")
        # Full path
        if folder.endswith("\\") or folder.endswith("/"):
            full_path = f"{folder}{name}"
        else:
            full_path = f"{folder}\\{name}" if "\\" in folder else f"{folder}/{name}"

        results.append({
            "filename": full_path,
            "type": item.get("type", "file"),
            "size": item.get("size", 0),
            "date_modified": filetime_to_iso(item.get("date_modified", 0))
        })

    return results


def find_es_binary():
    es_in_path = shutil.which("es") or shutil.which("es.exe")
    if es_in_path:
        return es_in_path

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


def search_via_cli(es_bin, query, limit=25, path=None, item_type="all", sort="default", as_json=False):
    cmd = [es_bin]
    if limit > 0:
        cmd.extend(["-n", str(limit)])
    if path and os.path.exists(path):
        cmd.extend(["-path", os.path.abspath(path)])
    if item_type in ("dir", "folder"):
        cmd.append("/ad")
    elif item_type == "file":
        cmd.append("/a-d")
    if sort == "dm":
        cmd.append("-sort-date-modified-descending")
    elif sort == "size":
        cmd.append("-sort-size-descending")
    elif sort == "name":
        cmd.append("-sort-name-ascending")

    cmd.extend(["-csv", "-size", "-date-modified"])
    cmd.append(query)

    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0 and proc.stderr:
        raise RuntimeError(f"es.exe failed: {proc.stderr.strip()}")

    stdout = proc.stdout.strip()
    if not stdout:
        return []

    reader = csv.DictReader(io.StringIO(stdout))
    results = []
    for row in reader:
        results.append({
            "filename": row.get("Filename", ""),
            "size": row.get("Size", ""),
            "date_modified": row.get("Date Modified", "")
        })
    return results


def main():
    parser = argparse.ArgumentParser(description="Search files via Everything (HTTP API or CLI)")
    parser.add_argument("query", help="Everything search query string")
    parser.add_argument("-p", "--path", help="Limit search to this folder")
    parser.add_argument("-n", "--limit", type=int, default=25, help="Max results (default: 25)")
    parser.add_argument("-t", "--type", choices=["all", "file", "dir", "folder"], default="all", help="Result type")
    parser.add_argument("-s", "--sort", choices=["default", "dm", "size", "name"], default="default", help="Sort order")
    parser.add_argument("--json", action="store_true", help="Output results as JSON")
    parser.add_argument("--mode", choices=["auto", "http", "cli"], default="auto", help="Search mechanism")
    parser.add_argument("--url", default=DEFAULT_HTTP_URL, help="Everything HTTP service URL")

    args = parser.parse_args()

    results = None
    last_error = None

    # Try HTTP Mode first if auto or forced http
    if args.mode in ("auto", "http"):
        try:
            results = search_via_http(args.url, args.query, limit=args.limit, path=args.path, item_type=args.type, sort=args.sort)
        except Exception as e:
            last_error = f"HTTP error ({args.url}): {e}"
            if args.mode == "http":
                sys.stderr.write(f"Error: {last_error}\n")
                sys.exit(1)

    # Fallback to CLI mode if auto failed or cli forced
    if results is None and args.mode in ("auto", "cli"):
        es_bin = find_es_binary()
        if es_bin:
            try:
                results = search_via_cli(es_bin, args.query, limit=args.limit, path=args.path, item_type=args.type, sort=args.sort, as_json=args.json)
            except Exception as e:
                sys.stderr.write(f"CLI error: {e}\n")
                if last_error:
                    sys.stderr.write(f"Previous HTTP attempt: {last_error}\n")
                sys.exit(1)
        else:
            msg = "Error: Neither Everything HTTP service nor es.exe CLI was accessible.\n"
            if last_error:
                msg += f"Details: {last_error}\n"
            msg += "Tip for sandboxed agents: Ensure Everything HTTP Server is enabled on the host (e.g. at http://127.0.0.1:8080 or http://host.docker.internal:8080).\n"
            sys.stderr.write(msg)
            sys.exit(1)

    # Output formatting
    if args.json:
        print(json.dumps(results if results else [], indent=2, ensure_ascii=False))
    else:
        if not results:
            return
        for r in results:
            print(r.get("filename", ""))


if __name__ == "__main__":
    main()
