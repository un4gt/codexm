# Cirrus CI Android Release Guide

Last updated: 2026-03-04

This project moved Android release automation from GitHub Actions self-hosted runners to Cirrus CI.

## What is in this repo now

- `/.cirrus.yml`: tag-triggered Android release pipeline on Cirrus CI.
- `/scripts/ci/publish_github_release.py`: creates/reuses GitHub Release and uploads APK assets.
- `/.github/workflows/android-release.yml`: removed.

## Trigger rules

The Cirrus task runs only when a pushed tag matches one of:

- `v*`
- `*-v*`

Example tags:

- `v1.2.3`
- `android-v1.2.3`

## Required Cirrus variables

Configure these in Cirrus repository settings:

- `GITHUB_TOKEN` (required): PAT with permission to create/update release and upload assets.
- `EXPO_TOKEN` (required): Expo access token for `eas update`.

Optional variables:

- `EAS_UPDATE_BRANCH` (default `production`)
- `CODEX_TERMUX_REPO`
- `CODEX_TERMUX_TAG`
- `RIPGREP_REPO`
- `RIPGREP_TAG`

## Compute services / pricing choices

From Cirrus pricing and compute-services docs, there are three practical options:

- Use public/free limits (suitable for OSS with low concurrency).
- Use compute credits for managed Cirrus clusters (no infra to maintain).
- Use your own compute services and pay seat-based plan for private repos.

Current `.cirrus.yml` uses Cirrus-managed Linux containers (`container`) with `ghcr.io/cirruslabs/android-sdk:36-ndk`.

## Pipeline behavior

For matched tags, the task does:

1. Install Node.js 22 and project dependencies.
2. Ensure Android SDK/NDK components.
3. Fetch Codex Android binaries (`scripts/fetch_android_codex_deps.py`).
4. Build release APK (`arm64-v8a`).
5. Upload APK to GitHub Release.
6. Publish Android EAS update.

## References

- Cirrus pricing and compute services: https://cirrus-ci.org/pricing/#compute-services
- Cirrus writing tasks (`only_if`, caches, artifacts): https://cirrus-ci.org/guide/writing-tasks/
- Cirrus Linux containers: https://cirrus-ci.org/guide/linux/
- Cirrus examples (Android): https://cirrus-ci.org/examples/
- Cirrus tips (`CIRRUS_CLONE_TAGS`): https://cirrus-ci.org/guide/tips-and-tricks/
