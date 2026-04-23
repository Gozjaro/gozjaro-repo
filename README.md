# gozjaro-repo

Package recipes for the [Gozjaro Linux](https://github.com/Gozjaro) base system.

Built with [gozpak](https://github.com/Gozjaro/gozpak) from LFS 12.3 sources.

## Install packages from the repo

```sh
echo 'https://github.com/Gozjaro/gozjaro-repo/releases/download/stable' > /etc/gozpak/repos.conf
gozpak sync
gozpak get curl
```

## Build from source

Point `GOZPAK_PATH` at this directory:

```sh
export GOZPAK_PATH=/path/to/gozjaro-repo
gozpak build zlib
gozpak install zlib
```

## Maintainer workflow

### 1. Build packages

```sh
export GOZPAK_PATH=/path/to/gozjaro-repo
gozpak repo-build -f packages.list -o ./repo
```

### 2. Generate repo index

```sh
gozpak repo-index ./repo
```

### 3. Upload to GitHub Releases

```sh
./scripts/repo-upload.sh ./repo stable
```

This uploads all tarballs + `repo.index` as assets on a GitHub Release
tagged `stable`. Clients point `GOZPAK_REPOS` at:

```
https://github.com/Gozjaro/gozjaro-repo/releases/download/stable
```

Requires [GitHub CLI](https://cli.github.com) (`gh`) authenticated.

### Generate real checksums

Recipes ship with `SKIP` checksums. To generate real SHA256 hashes:

```sh
# Single package
gozpak checksum zlib

# All packages
for pkg in */; do [ -f "$pkg/build" ] && gozpak checksum "${pkg%/}"; done
```

## Recipe format

Each directory is a package recipe:

| File | Required | Description |
|------|----------|-------------|
| `build` | yes | Shell script; `$1` = DESTDIR |
| `version` | yes | `<version> <release>` |
| `depends` | no | One dependency per line |
| `sources` | no | Source URLs (`VERSION` is substituted) |
| `checksums` | no | SHA256 per source, or `SKIP` |
| `meta` | no | Metadata (type, description, license) |

## Package count

85 packages covering the full LFS 12.3 base system, gozpak itself,
networking tools (curl, wget, openssh, git, rsync), and disk utilities
(parted, dosfstools, libarchive).

## License

MIT
