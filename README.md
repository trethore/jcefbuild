# JCEF BUILD

![build](../../actions/workflows/build.yml/badge.svg)

Independent project to produce binary artifacts for the JCEF project.

- JCEF source: [Bitbucket](https://bitbucket.org/chromiumembedded/java-cef/src/master/) or [GitHub](https://github.com/chromiumembedded/java-cef)
- Maven/Gradle consumers: [jcefmaven](https://github.com/jcefmaven/jcefmaven)

## Supported platforms

- linux-amd64
- linux-arm64
- macosx-amd64
- macosx-arm64
- windows-amd64

## Build environment (GitHub Actions)

| Platform | Build environment |
| --- | --- |
| Linux | Docker build (see `DockerfileLinux` for the toolchain and base image) |
| Windows | Docker build with VS Build Tools 2022 inside a Windows container |
| macOS | GitHub runner toolchain (Xcode + Ninja) plus `scripts/install_macos_dependencies.sh`; Java: Corretto 8; Python: 3.10.11 |

## Downloading artifacts

You can find the most recent versions of the artifacts on the
[releases](../../releases) page of this repository.

## Building via GitHub Actions

The `build` workflow is manual-only (`workflow_dispatch`) and supports the
following inputs:

- `jcef_repo` (default: `https://github.com/trethore/jcef`)
- `jcef_ref` (default: `master`)
- `platform` (default: `all`)
  - `all`, `linux-amd64`, `linux-arm64`, `macosx-amd64`, `macosx-arm64`, `windows-amd64`
- `sign_macosx` (default: `false`)
- `dry_run` (default: `true`)
  - `true`: build + upload action artifacts only
  - `false`: create a release and upload the binaries
    (plus `build_meta.json` and `LICENSE`)

### macOS signing secrets

If `sign_macosx` is enabled, you must set these repository secrets:

- `APPLE_API_KEY_BASE64`
- `APPLE_API_KEY_ISSUER`
- `APPLE_API_KEY_NAME`
- `APPLE_API_KEY_ID`
- `APPLE_BUILD_CERTIFICATE_BASE64`
- `APPLE_BUILD_CERTIFICATE_NAME`
- `APPLE_P12_PASSWORD`
- `APPLE_KEYCHAIN_PASSWORD`
- `APPLE_TEAM_NAME`

You can obtain:

- the API key from [App Store Connect](https://appstoreconnect.apple.com/access/api)
- the certificate from
  [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates/list)
  (use _Developer ID Application_)

## Building locally

Put your sources in the `jcef/` directory (or leave it empty to clone a repository),
then run:

- Linux: `./compile_linux.sh <arch> <buildType> [<gitrepo> <gitref>]`
- Windows: `compile_windows.bat <arch> <buildType> [<gitrepo> <gitref>]`
- macOS: `./compile_macosx.sh <arch> <buildType> [<gitrepo> <gitref>]`

Notes:

- Linux and Windows builds run inside Docker. Docker must be installed and running.
- macOS builds require the dependencies listed in the JCEF build guide and `ninja`.
- To match GitHub Actions on macOS, use Java 8 (Corretto) and Python 3.10.x.

## Reporting bugs

Please report build issues here.
For JCEF/CEF issues, use the
[ChromiumEmbedded Bitbucket tracker](https://bitbucket.org/chromiumembedded/).

## Contributing

Pull requests are welcome.
Please include a successful GitHub Actions run with your changes.

---

Credit: https://github.com/jcefmaven/jcefbuild
