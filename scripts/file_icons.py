#!/usr/bin/env python3
"""Decorate fd's NUL-delimited paths with Neovim's exported file icons."""
import json
import os
import sys


def icon_for(path, mapping):
    name = os.fsdecode(path.rsplit(b"/", 1)[-1]).lower()
    if name in mapping["files"]:
        return mapping["files"][name]
    while "." in name:
        name = name.split(".", 1)[1]
        if name in mapping["extensions"]:
            return mapping["extensions"][name]
    return mapping["default"]


def decorate(source, target, mapping):
    pending = b""
    while chunk := source.read1(65536):
        records = (pending + chunk).split(b"\0")
        pending = records.pop()
        for path in records:
            if path:
                target.write(icon_for(path, mapping).encode("utf-8") + b"\t" + path + b"\0")
        target.flush()
    if pending:
        target.write(icon_for(pending, mapping).encode("utf-8") + b"\t" + pending + b"\0")
    target.flush()


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8") as config:
        mapping = json.load(config)
    try:
        decorate(sys.stdin.buffer, sys.stdout.buffer, mapping)
    except BrokenPipeError:
        # fzf may close its input as soon as a selection is accepted/cancelled.
        os._exit(0)
