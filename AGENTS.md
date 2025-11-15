# Repository Guidelines

Use this guide to stay consistent while extending the build infrastructure that produces JCEF artifacts across Linux, macOS, and Windows.

## Project Structure & Module Organization
Top-level scripts (`compile_linux.sh`, `compile_macosx.sh`, `compile_windows.bat`) orchestrate builds per platform. Container definitions live under `docker/`, and helper utilities (patching, runners, dependency installers) sit in `scripts/`. Drop upstream sources into `jcef/` when you want to bypass cloning, keep notarization inputs in `entitlements/` and macOS signing helpers in the `macosx_*.sh` scripts, and store arm-native replacement jars in `natives/`. Release automation lives in `release_gen/`.

## Build, Test, and Development Commands
- `./compile_linux.sh amd64 Release [repo ref]`: runs Docker Buildx with Ninja, syncs artifacts into `jcef/binary_distrib`.
- `./compile_macosx.sh arm64 Release`: drives a local toolchain build; combine with `macosx_codesign.sh` and `macosx_notarize.sh` before distribution.
- `./compile_windows.bat amd64 Debug`: invokes the Windows Dockerfile and VS toolchain through Buildx.
- `bash release_gen/create_release_info.sh`: generates changelog snippets after a successful matrix run.
Prefix commands with `BUILDX_CACHE_ROOT=/path/to/cache` to persist Docker layers between runs.

## Coding Style & Naming Conventions
Shell scripts use `set -euo pipefail`, two-space indentation, and uppercase env vars (e.g., `TARGETARCH`, `BUILD_TYPE`). Python helpers (such as `scripts/patch_cmake.py`) follow PEP 8 snake_case. Windows batch files mirror the shell naming but keep CRLF endings. Keep Dockerfiles declarative: add build arguments near the top, and label reusable layers with `jcefbuild=true` for pruning.

## Testing Guidelines
There is no standalone automated test suite; treat each successful `binary_distrib` build as the verification step. Before opening a PR, run the relevant `compile_*` script locally, unpack `jcef/binary_distrib/<platform>` and launch the sample app to confirm Chromium starts. When changing native assets, ensure both amd64 and arm64 artifacts can be produced, and include proof (console logs or archive listings) in the PR.

## Commit & Pull Request Guidelines
Follow the existing history: short, imperative commit titles (`Remove unused output variables`). Group platform-specific changes per commit. Every PR must link to a passing GitHub Actions `build` workflow, describe the target OS/arch, and mention any signing credentials required. Attach diff summaries or screenshots when altering release scripts, and highlight whether downstream build caches must be cleared.

## Security & Configuration Tips
Store Apple signing inputs as Actions secrets (`APPLE_*`) and never hardcode them. On Linux/Windows, prefer build agents with Docker Buildx enabled; avoid Snap Docker because it breaks QEMU emulation. Clear sensitive artifacts by deleting `out/` before committing, and always scrub `jcef/binary_distrib` from version control.
