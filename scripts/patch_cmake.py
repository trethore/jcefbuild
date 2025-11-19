# Small script to patch CMakeLists.txt files with custom build options.
# Replaces file contents between two markers ("Determine the platform"
# and "Add this project's cmake") while bumping the minimum CMake version.
# Usage: python patch_cmake.py <input> <patch>

import argparse
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Patch CMakeLists.txt markers")
    parser.add_argument("cmake_file", type=Path)
    parser.add_argument("patch_file", type=Path)
    args = parser.parse_args()

    cmake_path = args.cmake_file
    patch_path = args.patch_file

    start_marker = "# Determine the platform"
    end_marker = "# Add this project's cmake"
    minimum_version = "cmake_minimum_required(VERSION 3.20)\n"

    cmake_lines = cmake_path.read_text().splitlines(keepends=True)
    patch_lines = patch_path.read_text().splitlines(keepends=True)

    result = []
    in_patch = False
    saw_start = False
    saw_end = False

    for line in cmake_lines:
        if line.startswith(start_marker):
            if saw_start:
                return _fail(f"Found duplicate start marker in {cmake_path}")
            saw_start = True
            in_patch = True
            result.extend(patch_lines)
            continue
        if line.startswith(end_marker):
            if not saw_start:
                return _fail(f"End marker appeared before start marker in {cmake_path}")
            saw_end = True
            in_patch = False
            result.append(line)
            continue
        if in_patch:
            continue
        if line.startswith("cmake_minimum_required"):
            result.append(minimum_version)
        else:
            result.append(line)

    if not saw_start or not saw_end:
        return _fail(f"Did not find both markers in {cmake_path}")

    cmake_path.write_text("".join(result))
    print(f"Patched {cmake_path} with {patch_path} (CMake >= 3.20)")
    return 0


def _fail(message: str) -> int:
    print(message, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
