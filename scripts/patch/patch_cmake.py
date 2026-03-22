import sys
from pathlib import Path

START_MARKER = "# Determine the platform"
END_MARKER = "# Add this project's cmake"


def patch_cmake(input_path: Path, patch_path: Path) -> None:
    print(f"Patching {input_path} to accept further build architectures...")

    source_lines = input_path.read_text(encoding="utf-8").splitlines(keepends=True)
    patch_lines = patch_path.read_text(encoding="utf-8").splitlines(keepends=True)

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

    input_path.write_text("".join(result_lines), encoding="utf-8")
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
