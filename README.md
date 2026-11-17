# gozjaro-repo

Package recipes for [Gozjaro Linux](https://github.com/Gozjaro), built with
[gozpak](https://github.com/Gozjaro/gozpak).

Gozjaro Linux 的软件包 recipe 仓库，使用 [gozpak](https://github.com/Gozjaro/gozpak) 构建。

## Layout / 目录结构

- `base/` — the 85-package LFS base system (26.11 build batch, built on the LFS VM).
  85 包 LFS 基础系统（26.11 批次，在 LFS VM 上编译）。
- `extra/` — the extra/desktop batch (191 packages, built on the 7D12 host).
  GUI/桌面批次（191 包，在 7D12 主机上编译）。
- `order/base.txt`, `order/extra.txt` — build orders for the batch drivers.
  批次驱动的构建顺序。
- `.signing/` (gitignored) — ed25519 seed for `gozpak sign`; the matching
  public key is embedded in gozpak (`EMBEDDED_PUBKEY`). The seed lives only on
  packaging hosts (7D12 `~/.secrets/gozjaro-repo.key` and the Mac copy), 0600.
  签名密钥：与 gozpak 内嵌公钥配对的 ed25519 种子，只保存在打包主机上（0600）。

Version policy since 26.11: recipes track **latest-stable upstream** releases,
not the LFS book (the base gcc stays at the 26.10 baseline 16.2.0).
26.11 起版本策略：recipe 跟随上游**最新稳定版**，不跟 LFS book（基础 gcc 保持 26.10 基线 16.2.0）。

## Install packages from the binary repo / 从二进制仓库安装

```sh
echo 'https://github.com/Gozjaro/gozjaro-repo/releases/download/stable' > /etc/gozpak/repos.conf
gozpak sync
gozpak get curl
```

Binary repos are GitHub releases holding `.gpkg` files plus a signed
`index.json` / `index.json.sig` (ed25519, verified against the public key
embedded in gozpak).
二进制仓库 = GitHub Release（`.gpkg` + 签名 `index.json`/`index.json.sig`，
gozpak 用内嵌公钥验签）。

## Publish a batch / 发布一个批次

Packaging host only (needs the signing seed + `gh`):

```sh
./scripts/publish.sh <dir-with-gpkgs> <release-tag>
```

This runs `gozpak index-build` + `gozpak sign` and uploads the `.gpkg` files,
`index.json` and `index.json.sig` to the GitHub release.
`scripts/publish.sh` 完成 index-build + sign + 上传 release。

## Build from source / 从源码构建

Point `GOZPAK_PATH` at `base/` or `extra/` (whichever tree you are building),
then run the batch driver (round-1 order, round-2 for stragglers):

```sh
GOZPAK_PATH=/opt/gozjaro-repo/base   # or extra/
gozpak repo-build <pkg>
```

## Build in a clean chroot / 在干净 chroot 里构建

Use an existing LFS root (default `/mnt/lfs`) as a read-only overlay lower layer.
使用已有的 LFS 根目录（默认 `/mnt/lfs`）作为只读下层，在临时 overlay 中构建。
```sh
sudo ./scripts/chroot-build.sh <pkg>...
sudo ./scripts/chroot-build.sh --shell      # interactive shell / 交互 shell
sudo ./scripts/chroot-build.sh --keep <pkg> # preserve upper layer / 保留上层以调试
```
Optional / 可选：`LFS`, `GOZPAK_REPOS`, `WORK` (默认 `/var/tmp/gozjaro-chroot`), `CACHE` (默认 `/var/cache/gozjaro`), `GOZPAK_GPKG`.
Sources / 源码缓存：`$CACHE/gozpak/sources`; packages / 成品包：`$CACHE/gozpak/bin`; gozpak downloads automatically if needed / 按需自动下载 gozpak。

## Recipe format / recipe 格式

Single-file `recipe.toml` per package (spec v1.2), one directory per package:
`[package]` (name/version/release/desc/license/depends), `[source]`
(urls + sha256, or git + pinned ref), `[build]` (system + steps), `[install]`.
每包一个目录、一个 `recipe.toml`（spec v1.2）。

## License

MIT
