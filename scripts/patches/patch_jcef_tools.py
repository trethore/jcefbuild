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


def patch_make_readme(path: Path) -> list[str]:
    if not path.exists():
        return []

    content = path.read_text(encoding="utf-8")
    patched = content
    changes: list[str] = []

    encoded_write = re.sub(
        r"(write_file\(\s*os\.path\.join\(\s*output_dir\s*,\s*['\"]README\.txt['\"]\s*\)\s*,\s*)"
        r"data\.encode\(\s*['\"]utf-8['\"]\s*\)(\s*\))",
        r"\1data\2",
        patched,
    )
    if encoded_write != patched:
        patched = encoded_write
        changes.append("Patched Python3 README generation compatibility")

    if "import glob\n" not in patched:
        updated_imports = patched.replace("import os\n", "import glob\nimport os\n")
        if updated_imports != patched:
            patched = updated_imports
            changes.append("Added glob import for README discovery")

    old_readme_lookup = "read_readme_file(os.path.join(jcef_dir, 'jcef_build', 'README.txt'), args)"
    new_readme_lookup = """readme_sources = [os.path.join(jcef_dir, 'jcef_build', 'README.txt')]\nreadme_sources.extend(glob.glob(os.path.join(jcef_dir, 'third_party', 'cef', 'cef_binary_*', 'README.txt')))\nfor readme_source in readme_sources:\n  if path_exists(readme_source):\n    read_readme_file(readme_source, args)\n    break\nelse:\n  raise Exception('Failed to locate CEF README.txt in jcef_build or third_party/cef')"""
    updated_lookup = patched.replace(old_readme_lookup, new_readme_lookup)
    if updated_lookup != patched:
        patched = updated_lookup
        changes.append("Added fallback CEF README discovery")

    if patched != content:
        path.write_text(patched, encoding="utf-8")

    if re.search(r"data\.encode\(\s*['\"]utf-8['\"]\s*\)", patched):
        raise RuntimeError("Failed to patch Python 3 README output handling")
    if re.search(
        r"read_readme_file\([^\n]*jcef_build[^\n]*README\.txt[^\n]*\)", patched
    ):
        raise RuntimeError("Failed to patch CEF README discovery")

    return changes


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
    readme_changes = patch_make_readme(tools_dir / "make_readme.py")

    if docs_perm_updated:
        print("Updated executable bit: make_docs.sh")
    if distrib_perm_updated:
        print("Updated executable bit: make_distrib.sh")
    for change in readme_changes:
        print(change)
    if not any([docs_perm_updated, distrib_perm_updated, *readme_changes]):
        print("No JCEF tools compatibility changes required")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
