#!/usr/bin/env python3
"""Sync a local directory to bunny.net Edge Storage.

Uploads every file under the given directory, deletes remote files under the
configured prefix that no longer exist locally, and uploads database files last
so pacman always sees a consistent repo.
"""

from __future__ import annotations

import hashlib
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import quote


def encode_object_rel(rel: str) -> str:
    return "/".join(quote(part, safe="") for part in rel.split("/"))


def mime_for(path: Path) -> str:
    guessed, _enc = mimetypes.guess_type(path.name)
    return guessed or "application/octet-stream"


def should_upload_db_last(path: Path) -> int:
    return 0 if path.name.endswith(".pkg.tar.zst") else 1


def get_json(url: str, access_key: str, timeout: int = 120) -> object:
    req = urllib.request.Request(
        url,
        method="GET",
        headers={"AccessKey": access_key},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read()
    return json.loads(body.decode("utf-8"))


def delete_path(url: str, access_key: str, timeout: int = 120) -> None:
    req = urllib.request.Request(
        url,
        method="DELETE",
        headers={"AccessKey": access_key},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            code = resp.getcode()
    except urllib.error.HTTPError as e:
        code = e.code
        if code == 404:
            return
        e.read(500)
        raise SystemExit(f"HTTP {code} DELETE {url}") from e
    else:
        if code not in (200, 201, 204):
            raise SystemExit(f"unexpected DELETE status {code} for {url}")


def put_file(
    url: str,
    body: bytes,
    access_key: str,
    content_type: str,
    max_attempts: int = 4,
) -> None:
    checksum = hashlib.sha256(body).hexdigest().upper()
    timeout = 600 if len(body) > 50_000_000 else 120
    for attempt in range(1, max_attempts + 1):
        req = urllib.request.Request(
            url,
            data=body,
            method="PUT",
            headers={
                "AccessKey": access_key,
                "Content-Type": content_type,
                "Checksum": checksum,
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                code = resp.getcode()
        except urllib.error.HTTPError as e:
            code = e.code
            err_body = e.read(500)
            if code in (200, 201):
                return
            if 500 <= code < 600 and attempt < max_attempts:
                time.sleep(0.5 * (2 ** (attempt - 1)))
                continue
            raise SystemExit(f"HTTP {code} for {url}: {err_body!r}") from e
        except (urllib.error.URLError, TimeoutError) as e:
            if attempt < max_attempts:
                time.sleep(0.5 * (2 ** (attempt - 1)))
                continue
            raise SystemExit(f"request failed for {url}: {e}") from e
        else:
            if code in (200, 201):
                return
            raise SystemExit(f"unexpected status {code} for {url}")


def list_remote_files(base: str, access_key: str, prefix: str) -> set[str]:
    base = base.rstrip("/")
    prefix = prefix.strip("/")
    found: set[str] = set()

    def walk(rel_dir: str) -> None:
        list_rel = rel_dir.strip("/")
        list_url = f"{base}/{encode_object_rel(list_rel)}/" if list_rel else f"{base}/"
        try:
            listing = get_json(list_url, access_key)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return
            raise
        if not isinstance(listing, list):
            return
        for item in listing:
            if not isinstance(item, dict):
                continue
            name = item.get("ObjectName")
            if not name or not isinstance(name, str):
                continue
            child = f"{list_rel}/{name}" if list_rel else name
            if item.get("IsDirectory"):
                walk(child)
            else:
                found.add(child)

    walk(prefix)
    return found


def upload_tree(
    root: Path,
    base: str,
    access_key: str,
    prefix: str,
) -> int:
    base = base.rstrip("/")
    prefix = prefix.strip("/")
    files = sorted(
        (p for p in root.rglob("*") if p.is_file()),
        key=lambda p: (should_upload_db_last(p), str(p)),
    )
    if not files:
        print(f"no files under {root}", file=sys.stderr)
        return 1

    local_rels: set[str] = set()
    for path in files:
        rel = path.relative_to(root).as_posix()
        object_rel = f"{prefix}/{rel}" if prefix else rel
        url = f"{base}/{encode_object_rel(object_rel)}"
        body = path.read_bytes()
        put_file(url, body, access_key, mime_for(path))
        print(url)
        local_rels.add(object_rel)

    remote = list_remote_files(base, access_key, prefix)
    for remote_rel in sorted(remote):
        if remote_rel in local_rels:
            continue
        url = f"{base}/{encode_object_rel(remote_rel)}"
        print(f"prune: DELETE {url}", file=sys.stderr)
        delete_path(url, access_key)

    return 0


def main() -> int:
    base = os.environ.get("BUNNY_STORAGE_BASE_URL", "").rstrip("/")
    key = os.environ.get("BUNNY_STORAGE_ACCESS_KEY", "")
    prefix = os.environ.get("BUNNY_STORAGE_OBJECT_PREFIX", "arch").strip("/")
    if not base or not key:
        print(
            "BUNNY_STORAGE_BASE_URL and BUNNY_STORAGE_ACCESS_KEY must be set",
            file=sys.stderr,
        )
        return 1
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <directory>", file=sys.stderr)
        return 1
    root = Path(sys.argv[1]).resolve()
    if not root.is_dir():
        print(f"not a directory: {root}", file=sys.stderr)
        return 1
    return upload_tree(root, base, key, prefix)


if __name__ == "__main__":
    raise SystemExit(main())
