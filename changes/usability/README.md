# WYCODE usability changes

This source changeset makes assessment entry, progress, and reports easier to use. The changes are applied and tested in the WYCODE development checkout. This repository distributes installers and binaries, so the reviewable source delta is published here without the development checkout's unrelated work or history. The reviewed changeset is included in the [v0.1.7 binary release](https://github.com/capibaras001/wycode/releases/tag/v0.1.7). The original patch and baseline hashes remain unchanged for traceability.

## Behavior

- The WYCODE home screen offers Chat, Assess project, and Assess target. Selecting a choice prepares an editable prompt. Assess project follows the selected directory, including after `/cd`.
- `/chat <question>` explicitly stays in chat. Common source filenames and file/line references such as `README.md:12` and `script.ts:42:8` no longer look like assessment domains. Existing local paths stay in chat; explicit `/start` targets and URLs retain assessment behavior.
- The assessment strip shows completed, running, pending, blocked, and cancelled counts, with active/blocking tasks and retry reasons. It restores older recorded plan results when reopening a session, using existing durable messages rather than a second state store. Headless output also shows progress and blockers.
- New finding notes require a supported severity and nonempty evidence. Invalid creates and updates fail before changing stored notes or findings. Historical notes still restore; rejected writes do not turn into findings on replay. Unverified candidates remain questions.
- Reports expose severity filtering, individual evidence, and the original full report. Keyboard users can use `/findings`, `/evidence`, and `/report` alongside the clickable controls. Existing reports without structured finding metadata still render their original text.

## Verification

The final validation ran against the actual development checkout:

| Check | Result |
| --- | --- |
| WYCODE package tests | 341 passed, 17 skipped, 0 failed |
| Native Core integration tests | 36 passed, 0 failed |
| Focused TUI usability tests | 11 passed, 0 failed |
| Full TUI suite | 1,489 passed, 4 skipped, 0 failed |
| Canonical root lint/type checks | 37 tasks passed |
| Whitespace validation | `git diff --check` passed |
| Change-package integrity | Patch applied to the pinned baseline and reproduced all 22 final file hashes |

The narrow-terminal regressions cover the home entry choices, task counts/blockers/retries, and report display at 44 columns. The interaction tests cover severity selection, evidence selection, return to the full report, project selection after `/cd`, and progress restoration from an older message page. Tests use local fixtures and recorded/fake model execution; they do not run assessments against external targets.

The package skips remain environmental/platform cases. TUI fixture teardown can emit temporary session-tab lock-file warnings; the test outcomes above are the runner's final counts. The changes have not been benchmarked for model quality or speed, and its original source-validation pass did not build binaries. The subsequent v0.1.7 release verification covers the compiled artifacts.

## Applying the delta

[`usability.patch`](usability.patch) contains only the 22 files changed by this work. [`manifest.json`](manifest.json) pins the patch digest and each file's before/after SHA-256. Some prerequisite native integration work in the development checkout is not part of the public distribution repository, so this patch is **not** intended to apply directly to this repository's `main` tree or to pristine upstream OpenCode.

In a matching development checkout, verify the manifest's before hashes, then run:

```sh
git apply --check /path/to/usability.patch
git apply /path/to/usability.patch
bun run check
cd packages/wycode
bun test --only-failures
cd ../core
bun run test test/plugin/wycode.test.ts
cd ../tui
bun run test
```

A null before hash denotes a new file. Keep any existing work when resolving a baseline mismatch; do not reset a checkout to force the patch to apply.

## Design references

The UI uses explicit entry choices, recorded progress, actionable blocking reasons, and evidence links, informed by the [Command Line Interface Guidelines](https://clig.dev/), [Microsoft Guidelines for Human-AI Interaction](https://www.microsoft.com/en-us/haxtoolkit/ai-guidelines/), and [GitHub's SARIF report documentation](https://docs.github.com/en/code-security/reference/code-scanning/sarif-files/sarif-support). It uses WYCODE's existing session, planning, finding, and theme facilities without adding a framework or dependency.
