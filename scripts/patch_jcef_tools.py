#!/usr/bin/env python3

import re
import stat
import sys
from pathlib import Path


def ensure_executable(path: Path) -> bool:
    if not path.exists():
        return False
    current_mode = path.stat().st_mode
    executable_mode = current_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH
    if executable_mode != current_mode:
        path.chmod(executable_mode)
        return True
    return False


def patch_make_readme(path: Path) -> bool:
    if not path.exists():
        return False

    content = path.read_text(encoding="utf-8")
    patched = re.sub(
        r"(write_file\(\s*os\.path\.join\(\s*output_dir\s*,\s*['\"]README\.txt['\"]\s*\)\s*,\s*)"
        r"data\.encode\(\s*['\"]utf-8['\"]\s*\)(\s*\))",
        r"\1data\2",
        content,
    )
    if patched != content:
        path.write_text(patched, encoding="utf-8")
        return True
    return False


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: patch_jcef_tools.py <tools_dir>")
        return 1

    tools_dir = Path(sys.argv[1]).resolve()
    if not tools_dir.is_dir():
        print(f"Skipping JCEF tools patching, directory not found: {tools_dir}")
        return 0

    docs_perm_updated = ensure_executable(tools_dir / "make_docs.sh")
    distrib_perm_updated = ensure_executable(tools_dir / "make_distrib.sh")
    readme_fixed = patch_make_readme(tools_dir / "make_readme.py")

    if docs_perm_updated:
        print("Updated executable bit: make_docs.sh")
    if distrib_perm_updated:
        print("Updated executable bit: make_distrib.sh")
    if readme_fixed:
        print("Patched Python3 README generation compatibility")
    if not any([docs_perm_updated, distrib_perm_updated, readme_fixed]):
        print("No JCEF tools compatibility changes required")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
