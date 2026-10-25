# Phase 2 report — classification (2026-10-25)

Input: `inventory/inventory.md` (62 REA-analyzed APKs + 2 dumpsys-evidence
packages) and baseline `device/runs/2026-10-25-143813/packages-system.txt`.

## Lists produced (lists/)

| List | Entries | Composition |
|---|---|---|
| debloat.txt | 12 | safe-to-disable verdicts minus voice (katniss) minus launcher feed (tvrecommendations); grouped into 3 batches: remoteota trio, vendor test/telemetry, Google one-shots |
| watchlist.txt | 9 | conditional entries, each with a one-line condition; launcher-suite items excluded (→ launcher-stock.txt) |
| protected.txt | 40 | 34 protected verdicts (incl. blerc, sei.hdmi.services, tvglobalkeyhandler — with evidence notes) + 2 /vendor-unreadable (dumpsys evidence) + 4 README-principle entries (systemui, netflix.ninja, netflix.tokenmanager, vending), marked |
| batch-voice.txt | 1 | com.google.android.katniss (only Assistant component on box; apps.googleassistant NOT installed — verified) |
| launcher-stock.txt | 4 | tvlauncher, tvrecommendations, leanbacklauncher.partnercustomizer, recents (launcherx variants checked: not present on this box) |

## Sanity checks — all green

- No package appears in more than one list (66 total entries, 66 unique)
- Every entry in every list exists verbatim in packages-system.txt
- Nothing from protected.txt appears in debloat / watchlist / batch-voice /
  launcher-stock
- Verdict distribution reconciled against the on-disk inventory table:
  14 safe-to-disable, 12 watchlist, 34 protected (36 incl. the 2
  vendor-unreadable), 2 keep. (An earlier session summary reported 12/13/36
  — the inventory table is authoritative.)

## Post-review addendum: com.android.tv.feedbackconsent

Flagged as a gap during review: present on-device but missed by the Phase 1
pull-targets pattern (it is com.android.*, not com.google.android.*).
Pulled and analyzed with the same REA pipeline before Phase 3:

- APK: /system_ext/priv-app/TvFeedbackConsent/TvFeedbackConsent.apk (2.0 MB),
  version 14, targetSdk 34
- No boot receivers; one service (TvFeedbackConsentService); permissions
  READ_LOGS + DUMP (diagnostic reads for the feedback flow only)
- No own telemetry endpoints (library noise only), no persist keys, no
  hardware gating
- Verdict: safe-to-disable (gates only the TV feedback/report prompts)
- Inventory updated (table row + section, count 61 → 62 APKs); added to
  debloat.txt Google one-shots batch (now 12 entries); sanity checks
  re-run clean after the addition.

Evidence: inventory/inventory.md, inventory/rea-json/, notes/progress-report.md.

## Next

Phase 3 per README: install Projectivy (preferences/projectivy.txt), verify
launch, set default home, confirm — only then disable launcher-stock.txt
entries. Then Phase 4 applies debloat.txt in batches of 3-5 with per-batch
verification (checklists/per-batch.md).
