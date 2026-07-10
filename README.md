# JCEF BUILD

![build](../../actions/workflows/build.yml/badge.svg)

[JCEF](https://github.com/trethore/jcef) provides Java bindings for the
Chromium Embedded Framework (CEF). This repository contains the scripts and
GitHub Actions workflow used to build JCEF binary distributions.

## Supported platforms

| Operating system | AMD64 | ARM64 |
| --- | :---: | :---: |
| Linux | `linux-amd64` | `linux-arm64` |
| macOS | `macosx-amd64` | `macosx-arm64` |
| Windows | `windows-amd64` | `windows-arm64` |

## GitHub Actions environments

| Platform | Environment |
| --- | --- |
| Linux | Docker Buildx on Ubuntu; ARM64 builds use QEMU |
| macOS | GitHub macOS runner with Xcode, Ninja, Java 17 and Python 3.10 |
| Windows | Windows Server 2022 container with Visual Studio Build Tools 2022; ARM64 uses cross-compilation |

## Downloading artifacts

Published builds are available on the [releases](../../releases) page.

Each release contains one archive per supported platform, Javadoc,
`build_meta.json`, and the JCEF license.

## Building using GitHub Actions

Open **Actions -> build -> Run workflow**, then configure:

| Input | Description |
| --- | --- |
| `jcef_repo` | JCEF repository to build |
| `jcef_ref` | Branch, tag, or commit to build |
| `platform` | A single platform or `all` |
| `sign_macosx` | Sign and notarize the macOS artifacts |
| `dry_run` | Upload workflow artifacts without publishing a release |

Use `dry_run=true` while testing changes. Partial platform builds are only
available in dry-run mode. Publishing a release requires `platform=all`; the
release becomes public only after every expected artifact has been built and
uploaded.

## Building locally

The `jcef/` directory is used as a persistent Git checkout. Leave it empty to
clone the requested repository, or place an existing Git checkout there. A
non-empty directory without `.git` is rejected.

```text
# Linux
./scripts/build/linux.sh <amd64|arm64> <Release|Debug> [<repository> <ref>]

# macOS
./scripts/build/macos.sh <amd64|arm64> <Release|Debug> [<repository> <ref>]

# Windows
scripts\build\windows.bat <amd64|arm64> <Release|Debug> [<repository> <ref>]
```

Linux and Windows require Docker. macOS requires Xcode, CMake, Ninja, Java 17,
Python 3.10, and the dependencies installed by `scripts/setup/macos.sh`.

Build results are written to `out/`.

## Sign macOS artifacts

Unsigned macOS builds are the default. To sign and notarize them in GitHub
Actions, enable `sign_macosx` and configure these repository secrets:

- `APPLE_API_KEY_BASE64`
- `APPLE_API_KEY_ISSUER`
- `APPLE_API_KEY_NAME`
- `APPLE_API_KEY_ID`
- `APPLE_BUILD_CERTIFICATE_BASE64`
- `APPLE_BUILD_CERTIFICATE_NAME`
- `APPLE_P12_PASSWORD`
- `APPLE_KEYCHAIN_PASSWORD`

Use a **Developer ID Application** certificate and an App Store Connect API
key. The workflow signs the application bundle, submits it to Apple's notary
service, and publishes the artifacts only if notarization succeeds.

## Support and issue routing

- Build scripts, workflow, or packaging problems -> report them in this repository.
- JCEF Java or native integration problems -> report them to [trethore/jcef](https://github.com/trethore/jcef).
- CEF or Chromium problems -> use the [Chromium Embedded Framework tracker](https://bitbucket.org/chromiumembedded/).

## Contributing

Pull requests are welcome.
Please include a successful GitHub Actions run with your changes.

## License

This project is available under the [Apache License 2.0](LICENSE).
Generated distributions also contain the license provided by JCEF.

## Credits

Based on the original [jcefmaven/jcefbuild](https://github.com/jcefmaven/jcefbuild)
project, with thanks to the JCEF and CEF contributors.
