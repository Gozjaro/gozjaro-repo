# gozjaro-repo

Package recipes for the [Gozjaro Linux](https://github.com/Gozjaro) base system.

Built with [gozpak](https://github.com/Gozjaro/gozpak) from LFS 12.3 sources.

## Usage

### As a source repository

Point `GOZPAK_PATH` at this directory to build packages from source:

```sh
export GOZPAK_PATH=/path/to/gozjaro-repo
gozpak build zlib
gozpak install zlib
```

### Batch build a binary repository

```sh
# Build all packages and output tarballs to ./repo
gozpak repo-build -f packages.list -o ./repo

# Generate the repo index
gozpak repo-index ./repo

# Push to a mirror
GOZPAK_REPO_PUSH_DEST=user@mirror:/srv/repo gozpak repo-push ./repo
```

### Install from the binary repo

```sh
echo 'https://repo.gozjaro.org/stable' > /etc/gozpak/repos.conf
gozpak sync
gozpak get curl
```

## Recipe format

Each directory is a package recipe:

| File | Required | Description |
|------|----------|-------------|
| `build` | yes | Shell script; `$1` = DESTDIR |
| `version` | yes | `<version> <release>` |
| `depends` | no | One dependency per line |
| `sources` | no | Source URLs (`VERSION` is substituted) |
| `meta` | no | Metadata (type, description, license) |

## Package count

84 packages covering the full LFS 12.3 base system plus networking tools
(curl, wget, openssh, git, rsync) and disk utilities (parted, dosfstools,
libarchive).

## License

MIT
