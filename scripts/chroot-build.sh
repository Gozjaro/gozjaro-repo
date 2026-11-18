#!/bin/bash
# Build with the LFS toolchain in a disposable overlay; keep downloads and packages.
set -euo pipefail

die() { echo "chroot-build: $*" >&2; exit 1; }
keep=false
shell=false
packages=()
for arg in "$@"; do
    case "$arg" in
        --keep) keep=true ;;
        --shell) shell=true ;;
        -*) die "unknown option: $arg" ;;
        *) packages+=("$arg") ;;
    esac
done
if $shell; then
    ((${#packages[@]} == 0)) || die "--shell cannot be combined with packages"
else
    ((${#packages[@]} > 0)) || die "usage: $0 [--keep] <pkg>... | [--keep] --shell"
fi
((EUID == 0)) || die "run as root (sudo $0 ...)"

LFS=$(realpath -m -- "${LFS:-/mnt/lfs}")
WORK=$(realpath -m -- "${WORK:-/var/tmp/gozjaro-chroot}")
CACHE=$(realpath -m -- "${CACHE:-/var/cache/gozjaro}")
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
[[ -f "$LFS/usr/bin/env" ]] || die "$LFS/usr/bin/env is missing; need a built LFS root"
# Reject overlaps before any mkdir/rm, including paths resolved through symlinks.
for pair in "$LFS|$WORK" "$LFS|$CACHE" "$WORK|$CACHE"; do
    a=${pair%%|*} b=${pair#*|}
    [[ "$a/" != "$b/"* && "$b/" != "$a/"* ]] || die "paths overlap: $a and $b"
done
merged=$WORK/merged
mountpoint -q -- "$merged" && die "$merged is already mounted (another run active)"
[[ ! -L "$merged" ]] || die "$merged must not be a symlink"

cleanup() {
    local status=$?
    trap - EXIT
    if mountpoint -q -- "$merged"; then
        umount -R -- "$merged" || umount -R -l -- "$merged" || {
            echo "chroot-build: unmount failed; preserving $WORK" >&2
            exit 1
        }
    fi
    if ! $keep; then rm -rf -- "$WORK/upper" "$WORK/work"; fi
    exit "$status"
}
rm -rf -- "$WORK/upper" "$WORK/work"
mkdir -p -- "$WORK/upper" "$WORK/work" "$merged" "$CACHE"
trap cleanup EXIT
mount -t overlay overlay -o "lowerdir=$LFS,upperdir=$WORK/upper,workdir=$WORK/work" "$merged"
mount --make-private "$merged"

mkdir -p "$merged"/{dev,proc,sys,run,etc,gozjaro-repo,var/cache/gozjaro}
mount --bind /dev "$merged/dev"
mount --make-private "$merged/dev"
mount --bind /dev/pts "$merged/dev/pts"
mount -t proc proc "$merged/proc"
mount -t sysfs sysfs "$merged/sys"
mount -t tmpfs tmpfs "$merged/run"
# Replace a possible absolute symlink instead of following it into the host.
rm -f -- "$merged/etc/resolv.conf"
cp /etc/resolv.conf "$merged/etc/resolv.conf"
mount --bind "$repo" "$merged/gozjaro-repo"
mount -o remount,bind,ro "$merged/gozjaro-repo"
mount --bind "$CACHE" "$merged/var/cache/gozjaro"

if [[ ! -e "$merged/usr/bin/gozpak" ]]; then
    default_gpkg=$CACHE/gozpak-6.0.0-1.gpkg
    GOZPAK_GPKG=${GOZPAK_GPKG:-$default_gpkg}
    if [[ ! -f "$GOZPAK_GPKG" ]]; then
        [[ "$GOZPAK_GPKG" == "$default_gpkg" ]] || die "package not found: $GOZPAK_GPKG"
        curl -fL https://github.com/Gozjaro/gozjaro-repo/releases/download/stable/gozpak-6.0.0-1.gpkg \
            -o "$default_gpkg.part"
        mv -- "$default_gpkg.part" "$default_gpkg"
    fi
    # .gpkg layout is ./rootfs/... — extract to a temp dir and copy
    # the payload into $merged (the existence check above and the
    # chroot PATH both expect /usr/bin/gozpak, not
    # $merged/rootfs/usr/bin/gozpak). Handle a flat payload too.
    tmpx=$(mktemp -d)
    tar --zstd -xf "$GOZPAK_GPKG" -C "$tmpx"
    if [[ -d "$tmpx/rootfs" ]]; then
        cp -a -- "$tmpx/rootfs/." "$merged/"
    else
        cp -a -- "$tmpx/." "$merged/"
    fi
    rm -rf -- "$tmpx"
fi

build_path=/usr/bin:/usr/sbin
extra_env=()
if [[ -e "$merged/usr/bin/ccache" ]]; then
    build_path=/usr/lib/ccache/bin:$build_path
    extra_env+=(CCACHE_DIR=/var/cache/gozjaro/ccache)
fi
# Pass the host's repo list through, so repo-build can fetch binary deps.
[[ -z "${GOZPAK_REPOS:-}" ]] || extra_env+=(GOZPAK_REPOS="$GOZPAK_REPOS")
if $shell; then
    command_args=(--login)
else
    command_args=(-ec 'for pkg; do gozpak repo-build "$pkg"; done' chroot-build "${packages[@]}")
fi
chroot "$merged" /usr/bin/env -i HOME=/root TERM="${TERM:-dumb}" \
    PATH="$build_path" MAKEFLAGS="-j$(nproc)" XDG_CACHE_HOME=/var/cache/gozjaro \
    GOZPAK_PATH=/gozjaro-repo/base:/gozjaro-repo/extra "${extra_env[@]}" \
    /bin/bash "${command_args[@]}"
echo "Built packages: $CACHE/gozpak/bin"
