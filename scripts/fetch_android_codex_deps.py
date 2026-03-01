#!/usr/bin/env python3
"""
下载并安装 Android 端 Codex 依赖到本仓库的 assets 目录（默认仅 arm64-v8a）。

产物路径：
  packages/codexm-native/android/src/main/assets/codex/<abi>/{codex,codex-exec,rg}

来源（默认）：
  - codex/codex-exec：DioNanos/codex-termux 的 GitHub Releases（Termux ARM64）
  - rg：microsoft/ripgrep-prebuilt 的 GitHub Releases（aarch64-unknown-linux-musl）

仅使用 Python 标准库。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tarfile
import tempfile
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional


GITHUB_API_BASE = 'https://api.github.com'
USER_AGENT = 'codexm-fetch-android-codex-deps'


@dataclass(frozen=True)
class ReleaseAsset:
  name: str
  url: str
  sha256: Optional[str]


def _github_token() -> Optional[str]:
  token = os.environ.get('GITHUB_TOKEN') or os.environ.get('GH_TOKEN')
  return token.strip() if token and token.strip() else None


def _http_get_bytes(url: str, *, headers: dict[str, str]) -> bytes:
  req = urllib.request.Request(url, headers=headers)
  with urllib.request.urlopen(req) as resp:  # nosec - URL is controlled by our code/args
    return resp.read()


def _http_download(url: str, dst: Path, *, headers: dict[str, str]) -> str:
  dst.parent.mkdir(parents=True, exist_ok=True)
  sha256 = hashlib.sha256()

  req = urllib.request.Request(url, headers=headers)
  with urllib.request.urlopen(req) as resp, open(dst, 'wb') as f:  # nosec - URL is controlled by our code/args
    while True:
      chunk = resp.read(1024 * 1024)
      if not chunk:
        break
      sha256.update(chunk)
      f.write(chunk)

  return sha256.hexdigest()


def _parse_sha256_digest(digest: Optional[str]) -> Optional[str]:
  if not digest:
    return None
  digest = digest.strip()
  if digest.startswith('sha256:'):
    return digest.split(':', 1)[1].strip() or None
  return None


def _github_release_asset(
  repo: str,
  *,
  tag: str,
  pick_asset_name: str,
) -> ReleaseAsset:
  token = _github_token()
  headers = {
    'User-Agent': USER_AGENT,
    'Accept': 'application/vnd.github+json',
  }
  if token:
    headers['Authorization'] = f'Bearer {token}'

  if tag == 'latest':
    url = f'{GITHUB_API_BASE}/repos/{repo}/releases/latest'
  else:
    url = f'{GITHUB_API_BASE}/repos/{repo}/releases/tags/{tag}'

  data = json.loads(_http_get_bytes(url, headers=headers).decode('utf-8'))
  assets = data.get('assets') or []
  for a in assets:
    if a.get('name') == pick_asset_name:
      return ReleaseAsset(
        name=a['name'],
        url=a['browser_download_url'],
        sha256=_parse_sha256_digest(a.get('digest')),
      )

  available = ', '.join([str(a.get('name')) for a in assets]) or '<none>'
  raise RuntimeError(f'找不到 Release asset：{repo}@{tag} / {pick_asset_name}（当前 assets: {available}）')


def _github_release_json(repo: str, *, tag: str) -> dict:
  token = _github_token()
  headers = {
    'User-Agent': USER_AGENT,
    'Accept': 'application/vnd.github+json',
  }
  if token:
    headers['Authorization'] = f'Bearer {token}'

  if tag == 'latest':
    url = f'{GITHUB_API_BASE}/repos/{repo}/releases/latest'
  else:
    url = f'{GITHUB_API_BASE}/repos/{repo}/releases/tags/{tag}'

  return json.loads(_http_get_bytes(url, headers=headers).decode('utf-8'))


def _github_releases_json(repo: str, *, per_page: int = 30) -> list[dict]:
  token = _github_token()
  headers = {
    'User-Agent': USER_AGENT,
    'Accept': 'application/vnd.github+json',
  }
  if token:
    headers['Authorization'] = f'Bearer {token}'

  url = f'{GITHUB_API_BASE}/repos/{repo}/releases?per_page={per_page}'
  data = json.loads(_http_get_bytes(url, headers=headers).decode('utf-8'))
  return data if isinstance(data, list) else []


def _is_elf_header(b: bytes) -> bool:
  return b.startswith(b'\x7fELF')


def _tar_members(tar: tarfile.TarFile) -> Iterable[tarfile.TarInfo]:
  for m in tar.getmembers():
    if m.isfile():
      yield m


def _extract_member_to_path(tar: tarfile.TarFile, member: tarfile.TarInfo, dst: Path) -> None:
  dst.parent.mkdir(parents=True, exist_ok=True)
  fileobj = tar.extractfile(member)
  if not fileobj:
    raise RuntimeError(f'无法读取压缩包成员：{member.name}')
  with open(dst, 'wb') as f:
    f.write(fileobj.read())

  # 在 *nix 下保证可执行；Windows 下无害
  try:
    mode = dst.stat().st_mode
    dst.chmod(mode | 0o111)
  except OSError:
    pass


def _extract_codex_termux_binaries(tgz_path: Path, out_dir: Path) -> None:
  with tarfile.open(tgz_path, mode='r:gz') as tar:
    min_size = 10 * 1024 * 1024
    elf_members: list[tarfile.TarInfo] = []

    for m in _tar_members(tar):
      if m.size < min_size:
        continue
      fileobj = tar.extractfile(m)
      if not fileobj:
        continue
      head = fileobj.read(4)
      if _is_elf_header(head):
        elf_members.append(m)

    if not elf_members:
      raise RuntimeError('在 codex-termux 压缩包中未找到 ELF 可执行文件（可能 release 包结构已变更）')

    def find_by_basename(basenames: set[str]) -> Optional[tarfile.TarInfo]:
      matches = [m for m in elf_members if Path(m.name).name in basenames]
      return max(matches, key=lambda m: m.size) if matches else None

    codex_member = find_by_basename({'codex'})
    exec_member = find_by_basename({'codex-exec', 'codex_exec'})

    if not codex_member:
      codex_member = max(elf_members, key=lambda m: m.size)

    if not exec_member:
      # 兜底：选择除 codex 之外第二大的 ELF
      sorted_by_size = sorted(elf_members, key=lambda m: m.size, reverse=True)
      exec_member = next((m for m in sorted_by_size if m.name != codex_member.name), None)

    if not exec_member or exec_member.name == codex_member.name:
      raise RuntimeError('无法同时定位 codex 与 codex-exec（可能 release 包结构已变更）')

    _extract_member_to_path(tar, codex_member, out_dir / 'codex')
    _extract_member_to_path(tar, exec_member, out_dir / 'codex-exec')


def _extract_ripgrep_rg(tar_gz_path: Path, out_dir: Path) -> None:
  with tarfile.open(tar_gz_path, mode='r:gz') as tar:
    rg_member: Optional[tarfile.TarInfo] = None
    for m in _tar_members(tar):
      if Path(m.name).name == 'rg' and m.size > 100_000:
        fileobj = tar.extractfile(m)
        if not fileobj:
          continue
        head = fileobj.read(4)
        if _is_elf_header(head):
          rg_member = m
          break

    if not rg_member:
      raise RuntimeError('在 ripgrep 压缩包中未找到 rg ELF 可执行文件')

    _extract_member_to_path(tar, rg_member, out_dir / 'rg')


def _repo_root() -> Path:
  here = Path(__file__).resolve()
  # scripts/<this_file> -> repo root
  return here.parents[1]


def _assets_out_dir(abi: str) -> Path:
  return (
    _repo_root()
    / 'packages'
    / 'codexm-native'
    / 'android'
    / 'src'
    / 'main'
    / 'assets'
    / 'codex'
    / abi
  )


def main(argv: list[str]) -> int:
  parser = argparse.ArgumentParser()
  parser.add_argument(
    '--abi',
    action='append',
    default=[],
    help='Android ABI（可重复）。默认：arm64-v8a',
  )

  parser.add_argument(
    '--codex-termux-repo',
    default=(os.environ.get('CODEX_TERMUX_REPO') or 'DioNanos/codex-termux'),
    help='GitHub repo（默认：DioNanos/codex-termux）',
  )
  parser.add_argument(
    '--codex-termux-tag',
    default=(os.environ.get('CODEX_TERMUX_TAG') or 'latest'),
    help='GitHub release tag（默认：latest）',
  )

  parser.add_argument(
    '--ripgrep-repo',
    default=(os.environ.get('RIPGREP_REPO') or 'microsoft/ripgrep-prebuilt'),
    help='GitHub repo（默认：microsoft/ripgrep-prebuilt）',
  )
  parser.add_argument(
    '--ripgrep-tag',
    default=(os.environ.get('RIPGREP_TAG') or 'v15.0.0'),
    help='GitHub release tag（默认：v15.0.0）',
  )

  args = parser.parse_args(argv)
  abis = args.abi or ['arm64-v8a']

  # ripgrep-prebuilt 资产命名依赖版本号（去掉 v 前缀）
  rg_version = args.ripgrep_tag[1:] if args.ripgrep_tag.startswith('v') else args.ripgrep_tag

  # 目前只对 arm64-v8a 提供确定可用的 codex-termux 来源；其它 ABI 默认跳过（仍可构建 APK，但 CodexRuntime 不可用）。
  supported_codex_abis = {'arm64-v8a'}
  rg_target_by_abi = {
    'arm64-v8a': 'aarch64-unknown-linux-musl',
  }

  token = _github_token()
  download_headers = {'User-Agent': USER_AGENT}
  if token:
    download_headers['Authorization'] = f'Bearer {token}'

  for abi in abis:
    out_dir = _assets_out_dir(abi)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f'== ABI: {abi} ==')
    print(f'输出目录: {out_dir}')

    if abi in supported_codex_abis:
      # codex-termux
      rel = _github_release_json(args.codex_termux_repo, tag=args.codex_termux_tag)
      assets = rel.get('assets') or []
      tgz_assets = [a for a in assets if str(a.get('name') or '').endswith('.tgz')]
      picked_tag = str(rel.get('tag_name') or args.codex_termux_tag)

      # GitHub 的 latest release 可能先发布（assets 还没上传），此时自动回退到最近一个包含 .tgz 的 release。
      if not tgz_assets and args.codex_termux_tag == 'latest':
        try:
          rels = _github_releases_json(args.codex_termux_repo)
        except Exception:
          rels = []
        for r in rels:
          if r.get('draft') or r.get('prerelease'):
            continue
          r_assets = r.get('assets') or []
          r_tgz = [a for a in r_assets if str(a.get('name') or '').endswith('.tgz')]
          if r_tgz:
            picked_tag = str(r.get('tag_name') or picked_tag)
            assets = r_assets
            tgz_assets = r_tgz
            print(
              f'提示：{args.codex_termux_repo}@latest 未包含 .tgz 资产，已回退到 {args.codex_termux_repo}@{picked_tag}',
            )
            break
      if not tgz_assets:
        available = ', '.join([str(a.get('name')) for a in assets]) or '<none>'
        raise RuntimeError(
          f'无法在 {args.codex_termux_repo}@{args.codex_termux_tag} 找到 .tgz 资产（当前 assets: {available}）',
        )

      a = tgz_assets[0]
      codex_asset = ReleaseAsset(
        name=a['name'],
        url=a['browser_download_url'],
        sha256=_parse_sha256_digest(a.get('digest')),
      )

      with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        codex_tgz = tmp / codex_asset.name
        print(f'下载 codex-termux: {codex_asset.url}')
        got_sha = _http_download(codex_asset.url, codex_tgz, headers=download_headers)
        if codex_asset.sha256 and got_sha.lower() != codex_asset.sha256.lower():
          raise RuntimeError(f'codex-termux sha256 校验失败：got {got_sha} expected {codex_asset.sha256}')

        _extract_codex_termux_binaries(codex_tgz, out_dir)

    else:
      print(f'跳过 codex/codex-exec：当前未提供 {abi} 的可用 codex-termux 二进制来源（仍可构建 APK）')

    rg_target = rg_target_by_abi.get(abi)
    if rg_target:
      rg_asset_name = f'ripgrep-v{rg_version}-{rg_target}.tar.gz'
      rg_asset = _github_release_asset(
        args.ripgrep_repo,
        tag=args.ripgrep_tag,
        pick_asset_name=rg_asset_name,
      )

      with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        rg_tgz = tmp / rg_asset.name
        print(f'下载 ripgrep: {rg_asset.url}')
        got_sha = _http_download(rg_asset.url, rg_tgz, headers=download_headers)
        if rg_asset.sha256 and got_sha.lower() != rg_asset.sha256.lower():
          raise RuntimeError(f'ripgrep sha256 校验失败：got {got_sha} expected {rg_asset.sha256}')

        _extract_ripgrep_rg(rg_tgz, out_dir)
    else:
      print(f'跳过 rg：当前脚本未配置 {abi} 的 ripgrep 目标三元组')

    for f in ('codex', 'codex-exec', 'rg'):
      p = out_dir / f
      if p.exists():
        print(f'✓ {p.name}: {p.stat().st_size} bytes')

  return 0


if __name__ == '__main__':
  raise SystemExit(main(sys.argv[1:]))
