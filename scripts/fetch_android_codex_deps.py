#!/usr/bin/env python3
"""
下载并安装 Android 端 Codex 依赖到本仓库的 assets 目录（默认仅 arm64-v8a）。

产物路径：
  packages/codexm-native/android/src/main/assets/codex/<abi>/{codex,codex-exec,rg}
  packages/codexm-native/android/src/main/assets/codex/<abi>/{libcodex_z.so,libcodex_lzma.so}

来源（默认）：
  - codex/codex-exec：DioNanos/codex-termux 的 GitHub Releases（Termux ARM64）
  - rg：microsoft/ripgrep-prebuilt 的 GitHub Releases（aarch64-unknown-linux-musl）
  - libcodex_z.so / libcodex_lzma.so：Termux main repo（用于满足 codex-termux 的版本化依赖，如 libz.so.1 / liblzma.so.5）

仅使用 Python 标准库。

备注：
  - 若本机存在 `readelf`，脚本会额外输出二进制的 DT_NEEDED 依赖列表（用于提前发现缺失的共享库）。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from io import BytesIO
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional


GITHUB_API_BASE = 'https://api.github.com'
USER_AGENT = 'codexm-fetch-android-codex-deps'
TERMUX_MAIN_REPO_BASE = 'https://packages.termux.dev/apt/termux-main'

_TERMUX_INDEX_CACHE: dict[tuple[str, str], dict[str, dict[str, str]]] = {}


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


def _raw_file_url(repo: str, *, ref: str, path: str) -> str:
  owner, name = repo.split('/', 1)
  p = path.lstrip('/')
  return f'https://raw.githubusercontent.com/{owner}/{name}/{ref}/{p}'


def _download_codex_termux_binaries_from_repo_tag(
  repo: str,
  *,
  tag: str,
  out_dir: Path,
  download_headers: dict[str, str],
) -> None:
  urls = [
    f'https://github.com/{repo}/archive/refs/tags/{tag}.tar.gz',
    f'https://github.com/{repo}/archive/refs/heads/{tag}.tar.gz',
  ]

  last_err: Optional[Exception] = None
  with tempfile.TemporaryDirectory() as tmpdir:
    tmp = Path(tmpdir)
    archive = tmp / f'{repo.replace("/", "-")}-{tag}.tar.gz'
    for url in urls:
      try:
        print(f'下载 codex-termux（tag 压缩包）: {url}')
        _http_download(url, archive, headers=download_headers)
        _extract_codex_termux_binaries(archive, out_dir)
        return
      except Exception as e:
        last_err = e

  raise RuntimeError(f'无法从 {repo}@{tag} 下载 codex-termux 源码包：{last_err}')


def _is_elf_header(b: bytes) -> bool:
  return b.startswith(b'\x7fELF')


def _is_versioned_so_name(name: str) -> bool:
  i = name.find('.so.')
  if i < 0:
    return False
  j = i + 4
  return j < len(name) and name[j].isdigit()


def _should_preflight_needed_lib(name: str) -> bool:
  if name == 'libc++_shared.so':
    return True
  return _is_versioned_so_name(name)


def _readelf_needed_libs(path: Path) -> list[str]:
  readelf = shutil.which('readelf')
  if not readelf:
    return []

  try:
    p = subprocess.run(  # nosec - tool is local; input is a repo file path
      [readelf, '-d', str(path)],
      check=False,
      stdout=subprocess.PIPE,
      stderr=subprocess.STDOUT,
      text=True,
    )
  except OSError:
    return []

  needed: list[str] = []
  for line in (p.stdout or '').splitlines():
    if 'NEEDED' not in line:
      continue
    # Example:
    #   0x0000000000000001 (NEEDED)             Shared library: [libz.so]
    lb = line.rfind('[')
    rb = line.rfind(']')
    if lb >= 0 and rb > lb:
      lib = line[lb + 1:rb].strip()
      if lib:
        needed.append(lib)

  # De-dupe while keeping order
  seen: set[str] = set()
  out: list[str] = []
  for lib in needed:
    if lib in seen:
      continue
    seen.add(lib)
    out.append(lib)
  return out


def _elf_needed_libs(path: Path) -> list[str]:
  # Minimal ELF parser for DT_NEEDED. Supports little-endian 32/64-bit.
  try:
    data = path.read_bytes()
  except OSError:
    return []

  if len(data) < 52:
    return []
  if not data.startswith(b'\x7fELF'):
    return []

  ei_class = data[4]
  ei_data = data[5]
  if ei_data != 1:  # little endian
    return []

  is64 = ei_class == 2
  if not is64 and ei_class != 1:
    return []

  def u16(off: int) -> int:
    return struct.unpack_from('<H', data, off)[0]

  def u32(off: int) -> int:
    return struct.unpack_from('<I', data, off)[0]

  def u64(off: int) -> int:
    return struct.unpack_from('<Q', data, off)[0]

  if is64:
    phoff = u64(32)
    phentsize = u16(54)
    phnum = u16(56)
  else:
    phoff = u32(28)
    phentsize = u16(42)
    phnum = u16(44)

  if phoff <= 0 or phentsize <= 0 or phnum <= 0:
    return []
  if phoff + (phentsize * phnum) > len(data):
    return []

  PT_LOAD = 1
  PT_DYNAMIC = 2

  load_segs: list[tuple[int, int, int, int]] = []  # (offset, vaddr, filesz, memsz)
  dynamic_seg: tuple[int, int, int] | None = None  # (offset, vaddr, filesz)

  for i in range(phnum):
    base = phoff + i * phentsize
    if base + phentsize > len(data):
      break
    if is64:
      p_type = u32(base + 0)
      p_offset = u64(base + 8)
      p_vaddr = u64(base + 16)
      p_filesz = u64(base + 32)
      p_memsz = u64(base + 40)
    else:
      p_type = u32(base + 0)
      p_offset = u32(base + 4)
      p_vaddr = u32(base + 8)
      p_filesz = u32(base + 16)
      p_memsz = u32(base + 20)

    if p_type == PT_LOAD:
      load_segs.append((int(p_offset), int(p_vaddr), int(p_filesz), int(p_memsz)))
    elif p_type == PT_DYNAMIC:
      dynamic_seg = (int(p_offset), int(p_vaddr), int(p_filesz))

  if not dynamic_seg or not load_segs:
    return []

  dyn_off, _dyn_va, dyn_filesz = dynamic_seg
  if dyn_off < 0 or dyn_filesz <= 0 or dyn_off + dyn_filesz > len(data):
    return []

  DT_NULL = 0
  DT_NEEDED = 1
  DT_STRTAB = 5
  DT_STRSZ = 10

  ent_size = 16 if is64 else 8
  needed_offsets: list[int] = []
  strtab_va: Optional[int] = None
  strsz: int = 0

  max_dyn = min(dyn_filesz, 1024 * 1024)
  for off in range(dyn_off, dyn_off + max_dyn, ent_size):
    if off + ent_size > len(data):
      break
    if is64:
      tag = struct.unpack_from('<q', data, off)[0]
      val = u64(off + 8)
    else:
      tag = struct.unpack_from('<i', data, off)[0]
      val = u32(off + 4)

    if tag == DT_NULL:
      break
    if tag == DT_NEEDED:
      needed_offsets.append(int(val))
    elif tag == DT_STRTAB:
      strtab_va = int(val)
    elif tag == DT_STRSZ:
      strsz = int(val)

  if not needed_offsets or strtab_va is None or strsz <= 0:
    return []

  # Translate strtab virtual address -> file offset using PT_LOAD segments.
  str_off: Optional[int] = None
  for seg_off, seg_va, seg_filesz, seg_memsz in load_segs:
    if strtab_va >= seg_va and strtab_va < seg_va + seg_memsz:
      str_off = seg_off + (strtab_va - seg_va)
      break
  if str_off is None:
    return []

  if str_off < 0 or str_off >= len(data):
    return []

  str_max = min(strsz, 8 * 1024 * 1024)
  end = min(len(data), str_off + str_max)
  strtab = data[str_off:end]

  out: list[str] = []
  seen: set[str] = set()
  for noff in needed_offsets:
    if noff < 0 or noff >= len(strtab):
      continue
    end0 = strtab.find(b'\x00', noff)
    if end0 < 0:
      continue
    try:
      s = strtab[noff:end0].decode('utf-8', errors='replace').strip()
    except Exception:
      continue
    if not s or s in seen:
      continue
    seen.add(s)
    out.append(s)
  return out


def _needed_libs(path: Path) -> list[str]:
  # Prefer readelf when available, but fall back to pure-Python parsing.
  out = _readelf_needed_libs(path)
  return out if out else _elf_needed_libs(path)


def _needed_lib_basenames(paths: Iterable[Path]) -> list[str]:
  libs: list[str] = []
  seen: set[str] = set()

  for p in paths:
    for name in _needed_libs(p):
      if not _should_preflight_needed_lib(name):
        continue

      base = name
      if _is_versioned_so_name(name):
        base = name.split('.so.', 1)[0] + '.so'

      if base in seen:
        continue
      seen.add(base)
      libs.append(base)

  return libs


def _http_get_text(url: str, *, headers: dict[str, str]) -> str:
  return _http_get_bytes(url, headers=headers).decode('utf-8', errors='replace')


def _termux_packages_index(arch: str, *, repo_base: str, headers: dict[str, str]) -> dict[str, dict[str, str]]:
  key = (repo_base, arch)
  cached = _TERMUX_INDEX_CACHE.get(key)
  if cached is not None:
    return cached

  url = f'{repo_base}/dists/stable/main/binary-{arch}/Packages.gz'
  raw = _http_get_bytes(url, headers=headers)
  try:
    import gzip
    text = gzip.decompress(raw).decode('utf-8', errors='replace')
  except OSError:
    # Not gzipped? Fall back to raw decode.
    text = raw.decode('utf-8', errors='replace')

  out: dict[str, dict[str, str]] = {}
  cur: dict[str, str] = {}

  def flush() -> None:
    nonlocal cur
    if cur.get('Package') and cur.get('Filename'):
      out[cur['Package']] = dict(cur)
    cur = {}

  for line in text.splitlines():
    if not line.strip():
      flush()
      continue
    if line[:1].isspace():
      # Continuation lines aren't needed for our keys.
      continue
    if ':' not in line:
      continue
    k, v = line.split(':', 1)
    cur[k.strip()] = v.strip()
  flush()
  _TERMUX_INDEX_CACHE[key] = out
  return out


def _ar_member_bytes(ar_path: Path, member_name: str) -> Optional[bytes]:
  # Minimal ar reader: enough for Debian .deb (ar) archives.
  with open(ar_path, 'rb') as f:
    magic = f.read(8)
    if magic != b'!<arch>\n':
      raise RuntimeError(f'无效 ar 归档（magic 不匹配）：{ar_path}')

    while True:
      hdr = f.read(60)
      if not hdr:
        break
      if len(hdr) != 60:
        raise RuntimeError(f'无效 ar header（长度不足）：{ar_path}')

      name = hdr[0:16].decode('utf-8', errors='replace').strip()
      size_raw = hdr[48:58].decode('utf-8', errors='replace').strip()
      end = hdr[58:60]
      if end != b'`\n':
        raise RuntimeError(f'无效 ar header（结束标记错误）：{ar_path}')
      try:
        size = int(size_raw)
      except ValueError as e:
        raise RuntimeError(f'无效 ar header size：{size_raw}') from e

      data = f.read(size)
      if len(data) != size:
        raise RuntimeError(f'无效 ar member（数据截断）：{ar_path}:{name}')
      if size % 2 == 1:
        # Members are 2-byte aligned; odd sizes are padded by one byte (newline).
        f.read(1)

      name = name.rstrip('/')
      if name == member_name:
        return data

  return None


def _extract_deb_data_tar(deb_path: Path) -> tuple[bytes, str]:
  for ext, mode in [
    ('.xz', 'r:xz'),
    ('.gz', 'r:gz'),
  ]:
    member = f'data.tar{ext}'
    b = _ar_member_bytes(deb_path, member)
    if b is not None:
      return b, mode
  raise RuntimeError(f'未找到 data.tar.*：{deb_path}')


def _extract_termux_shared_lib_bytes(deb_path: Path, lib_basename: str) -> bytes:
  data, mode = _extract_deb_data_tar(deb_path)
  with tarfile.open(fileobj=BytesIO(data), mode=mode) as tar:
    candidates: list[tarfile.TarInfo] = []
    for m in _tar_members(tar):
      base = Path(m.name).name
      if base == lib_basename or base.startswith(lib_basename + '.'):
        candidates.append(m)

    if not candidates:
      raise RuntimeError(f'在 Termux 包中未找到 {lib_basename}：{deb_path}')

    picked = max(candidates, key=lambda m: m.size)
    fileobj = tar.extractfile(picked)
    if not fileobj:
      raise RuntimeError(f'无法读取 Termux 包成员：{picked.name}')

    b = fileobj.read()
    if not _is_elf_header(b[:4]):
      raise RuntimeError(f'提取到的 {lib_basename} 不是 ELF：{picked.name}')
    return b


def _download_termux_deb(
  package_name: str,
  *,
  arch: str,
  repo_base: str,
  headers: dict[str, str],
  out_dir: Path,
) -> Path:
  index = _termux_packages_index(arch, repo_base=repo_base, headers=headers)
  meta = index.get(package_name)
  if not meta:
    raise RuntimeError(f'Termux repo 未找到包：{package_name}（arch={arch}）')

  filename = meta.get('Filename') or ''
  if not filename:
    raise RuntimeError(f'Termux repo 包缺少 Filename：{package_name}（arch={arch}）')

  url = f'{repo_base}/{filename.lstrip("/")}'
  dst = out_dir / Path(filename).name
  print(f'下载 Termux 包: {package_name} ({meta.get("Version")})')
  print(f'  - {url}')
  _http_download(url, dst, headers=headers)
  return dst


def _print_needed_libs(path: Path) -> None:
  needed = _needed_libs(path)
  if not needed:
    return

  interesting = [n for n in needed if _should_preflight_needed_lib(n)]
  if not interesting:
    return

  print(f'依赖检查（DT_NEEDED）: {path.name}')
  for n in interesting:
    print(f'  - {n}')
  print('提示：以上依赖通常不是 Android 系统自带，需要随 APK 一起打包到 nativeLibraryDir 并确保可被动态链接器找到。')


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
    def is_elf(m: tarfile.TarInfo) -> bool:
      fileobj = tar.extractfile(m)
      if not fileobj:
        return False
      head = fileobj.read(4)
      return _is_elf_header(head)

    # 优先按文件名精确匹配（避免仅靠大小阈值导致漏检）。
    by_basename: dict[str, list[tarfile.TarInfo]] = {
      'codex': [],
      'codex-exec': [],
      'codex_exec': [],
    }
    for m in _tar_members(tar):
      base = Path(m.name).name
      if base not in by_basename:
        continue
      try:
        if is_elf(m):
          by_basename[base].append(m)
      except OSError:
        continue

    codex_member = max(by_basename['codex'], key=lambda m: m.size) if by_basename['codex'] else None
    exec_candidates = [*by_basename['codex-exec'], *by_basename['codex_exec']]
    exec_member = max(exec_candidates, key=lambda m: m.size) if exec_candidates else None

    if codex_member and exec_member and exec_member.name != codex_member.name:
      _extract_member_to_path(tar, codex_member, out_dir / 'codex')
      _extract_member_to_path(tar, exec_member, out_dir / 'codex-exec')
      return

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

  parser.add_argument(
    '--termux-main-repo-base',
    default=(os.environ.get('TERMUX_MAIN_REPO_BASE') or TERMUX_MAIN_REPO_BASE),
    help=f'Termux main repo base URL（默认：{TERMUX_MAIN_REPO_BASE}）',
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
  termux_arch_by_abi = {
    'arm64-v8a': 'aarch64',
  }

  # Map DT_NEEDED base SONAME -> Termux package name.
  termux_pkg_for_lib = {
    'liblzma.so': 'liblzma',
    'libz.so': 'zlib',
  }
  # Output filenames under assets (avoid clobbering system lib names like liblzma.so / libz.so).
  termux_asset_for_lib = {
    'liblzma.so': 'libcodex_lzma.so',
    'libz.so': 'libcodex_z.so',
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
      tgz_assets = [
        a
        for a in assets
        if str(a.get('name') or '').endswith('.tgz') or str(a.get('name') or '').endswith('.tar.gz')
      ]
      tgz_assets.sort(key=lambda a: 0 if str(a.get('name') or '').endswith('.tgz') else 1)
      picked_tag = str(rel.get('tag_name') or (args.codex_termux_tag if args.codex_termux_tag != 'latest' else 'main'))

      if tgz_assets:
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
        # 兼容：latest release 可能暂时没有 .tgz/.tar.gz 资产；此时改为从 tag 源码包中提取二进制。
        available = ', '.join([str(a.get('name')) for a in assets]) or '<none>'
        print(
          f'提示：{args.codex_termux_repo}@{args.codex_termux_tag} 未提供 .tgz/.tar.gz 资产（当前 assets: {available}），'
          '改为从 tag 源码包中提取二进制。'
        )
        _download_codex_termux_binaries_from_repo_tag(
          args.codex_termux_repo,
          tag=picked_tag,
          out_dir=out_dir,
          download_headers=download_headers,
        )

      # Termux shared library dependencies (e.g. liblzma.so.5, libz.so.1)
      # Fetch base libs into assets as unversioned names (lib*.so). Android runtime will create
      # versioned aliases (lib*.so.N) at launch time when needed.
      codex_path = out_dir / 'codex'
      codex_exec_path = out_dir / 'codex-exec'
      if codex_path.exists() and codex_exec_path.exists():
        needed_bases = _needed_lib_basenames([codex_path, codex_exec_path])

        unknown: list[str] = []
        for base in needed_bases:
          if base == 'libc++_shared.so':
            # Usually already shipped by the app (NDK STL c++_shared). We avoid bundling another
            # copy here to prevent duplicate packaging conflicts.
            continue
          if base not in termux_pkg_for_lib or base not in termux_asset_for_lib:
            unknown.append(base)

        if unknown:
          raise RuntimeError(
            '检测到未配置下载来源的共享库依赖：\n' +
            '\n'.join([f'  - {x}' for x in unknown]) +
            '\n请更新 scripts/fetch_android_codex_deps.py 中 termux_pkg_for_lib 映射后重试。'
          )

        termux_arch = termux_arch_by_abi.get(abi)
        if needed_bases and not termux_arch:
          raise RuntimeError(f'未配置 Termux arch 映射：abi={abi}')

        if termux_arch:
          with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            for base in needed_bases:
              pkg = termux_pkg_for_lib.get(base)
              if not pkg:
                continue

              deb = _download_termux_deb(
                pkg,
                arch=termux_arch,
                repo_base=args.termux_main_repo_base,
                headers=download_headers,
                out_dir=tmp,
              )
              lib_bytes = _extract_termux_shared_lib_bytes(deb, base)
              dst = out_dir / termux_asset_for_lib[base]
              dst.write_bytes(lib_bytes)
              try:
                mode = dst.stat().st_mode
                dst.chmod(mode | 0o111)
              except OSError:
                pass
              print(f'✓ {dst.name}: {dst.stat().st_size} bytes')

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

    for f in ('codex', 'codex-exec', 'rg', 'libcodex_z.so', 'libcodex_lzma.so'):
      p = out_dir / f
      if p.exists():
        print(f'✓ {p.name}: {p.stat().st_size} bytes')
        _print_needed_libs(p)

  return 0


if __name__ == '__main__':
  raise SystemExit(main(sys.argv[1:]))
