#!/usr/bin/env python3
"""
Create or reuse a GitHub release for a tag and upload binary assets.

This script is designed for Cirrus CI but can run anywhere with:
  - GITHUB_TOKEN (or GH_TOKEN)
  - repo/tag metadata via args or environment variables
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


GITHUB_API_BASE = 'https://api.github.com'
USER_AGENT = 'codexm-cirrus-release'


class GitHubAPIError(RuntimeError):
  def __init__(self, status: int, url: str, body: str) -> None:
    super().__init__(f'GitHub API {status} for {url}: {body[:400]}')
    self.status = status
    self.url = url
    self.body = body


def _token() -> str:
  token = (os.environ.get('GITHUB_TOKEN') or os.environ.get('GH_TOKEN') or '').strip()
  if not token:
    raise RuntimeError('Missing GITHUB_TOKEN (or GH_TOKEN).')
  return token


def _json_request(
  method: str,
  url: str,
  *,
  token: str,
  payload: dict[str, Any] | None = None,
  headers: dict[str, str] | None = None,
) -> dict[str, Any]:
  req_headers = {
    'Accept': 'application/vnd.github+json',
    'Authorization': f'Bearer {token}',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': USER_AGENT,
  }
  if headers:
    req_headers.update(headers)

  data = None
  if payload is not None:
    req_headers['Content-Type'] = 'application/json'
    data = json.dumps(payload).encode('utf-8')

  req = urllib.request.Request(url=url, method=method, headers=req_headers, data=data)
  try:
    with urllib.request.urlopen(req) as resp:  # nosec - URL is controlled in code/args
      raw = resp.read().decode('utf-8')
      if not raw:
        return {}
      return json.loads(raw)
  except urllib.error.HTTPError as exc:
    body = exc.read().decode('utf-8', errors='replace')
    raise GitHubAPIError(exc.code, url, body) from exc


def _empty_request(
  method: str,
  url: str,
  *,
  token: str,
  headers: dict[str, str] | None = None,
) -> None:
  req_headers = {
    'Accept': 'application/vnd.github+json',
    'Authorization': f'Bearer {token}',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': USER_AGENT,
  }
  if headers:
    req_headers.update(headers)

  req = urllib.request.Request(url=url, method=method, headers=req_headers)
  try:
    with urllib.request.urlopen(req):  # nosec - URL is controlled in code/args
      return
  except urllib.error.HTTPError as exc:
    body = exc.read().decode('utf-8', errors='replace')
    raise GitHubAPIError(exc.code, url, body) from exc


def _binary_upload(
  upload_url: str,
  *,
  token: str,
  file_path: Path,
) -> dict[str, Any]:
  content_type = (
    'application/vnd.android.package-archive'
    if file_path.suffix.lower() == '.apk'
    else (mimetypes.guess_type(file_path.name)[0] or 'application/octet-stream')
  )

  data = file_path.read_bytes()
  headers = {
    'Accept': 'application/vnd.github+json',
    'Authorization': f'Bearer {token}',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': USER_AGENT,
    'Content-Type': content_type,
    'Content-Length': str(len(data)),
  }
  req = urllib.request.Request(url=upload_url, method='POST', headers=headers, data=data)
  try:
    with urllib.request.urlopen(req) as resp:  # nosec - URL is controlled in code/args
      raw = resp.read().decode('utf-8')
      return json.loads(raw) if raw else {}
  except urllib.error.HTTPError as exc:
    body = exc.read().decode('utf-8', errors='replace')
    raise GitHubAPIError(exc.code, upload_url, body) from exc


def _get_release_by_tag(repo: str, tag: str, *, token: str) -> dict[str, Any] | None:
  url = f'{GITHUB_API_BASE}/repos/{repo}/releases/tags/{urllib.parse.quote(tag)}'
  try:
    return _json_request('GET', url, token=token)
  except GitHubAPIError as err:
    if err.status == 404:
      return None
    raise


def _create_release(
  repo: str,
  tag: str,
  *,
  token: str,
  target_commitish: str | None,
  release_name: str | None,
) -> dict[str, Any]:
  url = f'{GITHUB_API_BASE}/repos/{repo}/releases'
  payload: dict[str, Any] = {
    'tag_name': tag,
    'name': release_name or tag,
    'draft': False,
    'prerelease': False,
    'generate_release_notes': True,
  }
  if target_commitish:
    payload['target_commitish'] = target_commitish
  return _json_request('POST', url, token=token, payload=payload)


def _delete_asset(repo: str, asset_id: int, *, token: str) -> None:
  url = f'{GITHUB_API_BASE}/repos/{repo}/releases/assets/{asset_id}'
  _empty_request('DELETE', url, token=token)


def _strip_upload_template(upload_url: str) -> str:
  # GitHub returns ".../assets{?name,label}"
  brace = upload_url.find('{')
  return upload_url[:brace] if brace >= 0 else upload_url


def _asset_upload_url(upload_url: str, file_name: str) -> str:
  base = _strip_upload_template(upload_url)
  return f'{base}?name={urllib.parse.quote(file_name)}'


def _parse_args(argv: list[str]) -> argparse.Namespace:
  parser = argparse.ArgumentParser()
  parser.add_argument(
    'assets',
    nargs='+',
    help='One or more file paths to upload as release assets.',
  )
  parser.add_argument(
    '--repo',
    default=(os.environ.get('CIRRUS_REPO_FULL_NAME') or os.environ.get('GITHUB_REPOSITORY') or ''),
    help='GitHub repository in owner/name format.',
  )
  parser.add_argument(
    '--tag',
    default=(os.environ.get('CIRRUS_TAG') or os.environ.get('GITHUB_REF_NAME') or ''),
    help='Release tag name.',
  )
  parser.add_argument(
    '--target-commitish',
    default=(os.environ.get('CIRRUS_CHANGE_IN_REPO') or ''),
    help='Commit SHA/branch to target when creating release.',
  )
  parser.add_argument(
    '--name',
    default='',
    help='Release title (default: tag).',
  )
  return parser.parse_args(argv)


def main(argv: list[str]) -> int:
  args = _parse_args(argv)
  token = _token()

  repo = args.repo.strip()
  tag = args.tag.strip()
  target_commitish = args.target_commitish.strip() or None
  release_name = args.name.strip() or None

  if not repo:
    raise RuntimeError('Missing repository name. Pass --repo or set CIRRUS_REPO_FULL_NAME/GITHUB_REPOSITORY.')
  if not tag:
    raise RuntimeError('Missing tag. Pass --tag or set CIRRUS_TAG/GITHUB_REF_NAME.')

  asset_paths = [Path(p) for p in args.assets]
  for p in asset_paths:
    if not p.is_file():
      raise RuntimeError(f'Asset not found: {p}')

  release = _get_release_by_tag(repo, tag, token=token)
  if release is None:
    print(f'Creating release for tag: {tag}')
    release = _create_release(
      repo,
      tag,
      token=token,
      target_commitish=target_commitish,
      release_name=release_name,
    )
  else:
    print(f'Using existing release: {release.get("html_url", "")}')

  upload_url_tpl = str(release.get('upload_url') or '')
  if not upload_url_tpl:
    raise RuntimeError('Release payload did not include upload_url.')

  existing_assets = release.get('assets') or []
  existing_by_name = {str(a.get('name')): a for a in existing_assets if a.get('name')}

  for asset_path in asset_paths:
    existing = existing_by_name.get(asset_path.name)
    if existing and existing.get('id') is not None:
      asset_id = int(existing['id'])
      print(f'Deleting existing asset with same name: {asset_path.name}')
      _delete_asset(repo, asset_id, token=token)

    upload_url = _asset_upload_url(upload_url_tpl, asset_path.name)
    print(f'Uploading asset: {asset_path}')
    uploaded = _binary_upload(upload_url, token=token, file_path=asset_path)
    print(f'Uploaded: {uploaded.get("browser_download_url", "")}')

  release_url = str(release.get('html_url') or '')
  if release_url:
    print(f'Release URL: {release_url}')
  return 0


if __name__ == '__main__':
  try:
    raise SystemExit(main(sys.argv[1:]))
  except Exception as exc:  # pragma: no cover - used in CI script mode
    print(f'ERROR: {exc}', file=sys.stderr)
    raise SystemExit(1)
