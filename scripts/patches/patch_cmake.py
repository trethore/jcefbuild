import sys
from pathlib import Path

START_MARKER = "# Determine the platform"
END_MARKER = "# Add this project's cmake"


def patch_cmake(input_path: Path, patch_path: Path) -> None:
    print(f"Patching {input_path} to accept further build architectures...")

    source_lines = input_path.read_text(encoding="utf-8").splitlines(keepends=True)
    patch_lines = patch_path.read_text(encoding="utf-8").splitlines(keepends=True)

    start_indexes = [i for i, line in enumerate(source_lines) if line.startswith(START_MARKER)]
    end_indexes = [i for i, line in enumerate(source_lines) if line.startswith(END_MARKER)]
    if len(start_indexes) != 1 or len(end_indexes) != 1:
        raise RuntimeError(
            "Expected exactly one CMake platform block, found "
            f"{len(start_indexes)} start marker(s) and {len(end_indexes)} end marker(s)"
        )
    if start_indexes[0] >= end_indexes[0]:
        raise RuntimeError("CMake platform block markers are in the wrong order")
    if not patch_lines or not patch_lines[0].startswith(START_MARKER):
        raise RuntimeError(f"Patch must begin with: {START_MARKER}")

    result_lines: list[str] = []
    in_patch_block = False
    patch_inserted = False

    for line in source_lines:
        if line.startswith(START_MARKER):
            in_patch_block = True
            if not patch_inserted:
                result_lines.extend(patch_lines)
                patch_inserted = True
            continue

        if line.startswith(END_MARKER):
            in_patch_block = False

        if not in_patch_block:
            result_lines.append(line)

    if not patch_inserted or in_patch_block:
        raise RuntimeError("Failed to replace the CMake platform block")

    result = "".join(result_lines)
    required_values = ("linuxarm64", "windowsarm64", "macosarm64")
    missing_values = [value for value in required_values if value not in result]
    if missing_values:
        raise RuntimeError(
            "Patched CMake configuration is missing required platforms: "
            + ", ".join(missing_values)
        )

    input_path.write_text(result, encoding="utf-8")
    print("Done.")


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: python patch_cmake.py <input> <patch>")
        return 1

    input_path = Path(sys.argv[1]).resolve()
    patch_path = Path(sys.argv[2]).resolve()

    patch_cmake(input_path, patch_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
