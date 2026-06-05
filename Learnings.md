---
title: AntigravityBar Learnings
purpose: Save hard-won lessons so future agents avoid the same mistakes.
update_rule: Read this file at the start of non-trivial work. Append new lessons after any bug, failed tool call, release issue, or other problem that took extra effort to solve.
last_updated: 2026-06-06
---

# Learnings

## Table of Contents

1. [How To Use This File](#how-to-use-this-file)
2. [Release And Notarization](#release-and-notarization)
3. [Runtime And CLI Integration](#runtime-and-cli-integration)

## How To Use This File

- Read this file before doing non-trivial work in this repo.
- Append new lessons. Do not delete old lessons unless they are clearly wrong.
- Keep each lesson short and practical.
- Prefer facts that prevent bad tool calls, broken releases, or repeat debugging.
- When you add a new section, also add it to the table of contents.
- When possible, write each lesson as `Problem -> Cause -> Fix`.

## Release And Notarization

### 2026-06-06: Notarized DMG release workflow

- Problem: a simple local Release archive is not enough for a trusted public DMG release.
  Cause: Xcode archived the app with local signing (`Sign to Run Locally`), which is fine for local use but not for public distribution.
  Fix: copy the archived app, re-sign that copy with `Developer ID Application: Linda Fitriani (2Z8N5KTWQZ)`, use hardened runtime and timestamp, then notarize and staple before public release.

- Problem: verifying the app with Gatekeeper before notarization gave a false-looking failure.
  Cause: an unnotarized Developer ID app is expected to fail trust checks before the notarization step is complete.
  Fix: do `codesign --verify` before notarization, but do trust-policy checks only after notarization and stapling.

- Problem: `spctl` returned `Too many open files` during final release verification even though the artifact was valid.
  Cause: on this machine and macOS version, `spctl` was flaky for this final check.
  Fix: use `syspolicy_check distribution` as the final distribution trust check for the stapled app and stapled DMG.

- Problem: `xcrun notarytool submit` rejected the raw `.app` bundle.
  Cause: `notarytool` wanted a supported container format instead of the bare app bundle.
  Fix: zip the signed `.app` with `ditto -c -k --keepParent`, submit the zip for notarization, then staple the `.app`.

- Problem: the app inside the DMG can still fail distribution checks even if the DMG itself is notarized.
  Cause: notarizing only the DMG is weaker than notarizing the app first and then the DMG.
  Fix: notarize and staple the signed app first, then build the DMG from that stapled app, then notarize and staple the DMG too.

- Problem: published checksum can become wrong late in the release flow.
  Cause: stapling changes the final DMG bytes.
  Fix: always generate the SHA-256 checksum after DMG stapling, not before.

- Problem: GitHub release creation can point at the wrong commit or fail.
  Cause: release publishing needs the full current commit as the target.
  Fix: create the release from the final pushed commit and use the full `git rev-parse HEAD` value for `gh release create --target`.

### 2026-06-06: Retry before changing the release script when signing looks wrong

- Problem: the first `script/build_release_dmg.sh 2026.06.06.2 --publish` run stopped with `A timestamp was expected but was not found`.
  Cause: the packaged app copy was still showing an ad-hoc signature even though the same Developer ID sign command succeeded right after.
  Fix: inspect the packaged app with `codesign -dvvv`; if it still shows `Signature=adhoc` or no timestamp, retry the exact Developer ID sign or rerun the release script once before changing code.

- Problem: a checkout/merge command failed once with `.git/index.lock`, then the lock file was already gone on the next check.
  Cause: a transient git lock can remain briefly after another git command finishes.
  Fix: check for a real running git process first, then retry once before deleting any lock file by hand.

## Runtime And CLI Integration

### 2026-06-06: GUI app found the CLI, but the CLI could not find `node`

- Problem: the menu bar app showed `env: node: No such file or directory` even though `antigravity-usage` was installed.
  Cause: the app launches `/opt/homebrew/bin/antigravity-usage` directly, but that file is a Node script with `#!/usr/bin/env node`, so it still depends on the app process `PATH` to find `node`. GUI-launched apps may not inherit the same Homebrew-friendly `PATH` as Terminal.
  Fix: when a bundled macOS app runs a Node-based CLI, either set `Process.environment["PATH"]` to include the Node location or call the Node binary directly with the CLI script path instead of relying on `/usr/bin/env node`.
