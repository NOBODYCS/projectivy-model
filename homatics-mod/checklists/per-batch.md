# Per-batch verification checklist

Automated (agent runs, attach results):
- [ ] `pm list packages -d` shows the whole batch as disabled
- [ ] Screenshot captured, home screen renders (or current app visible)
- [ ] `am start` succeeds: Netflix, YouTube, Settings
- [ ] `logcat -d *:E` — no new crashes/ANRs from disabled packages
- [ ] `dumpsys activity processes` — no repeated restart loops

Manual (human confirms on TV):
- [ ] Home renders and is navigable
- [ ] Netflix launches AND video plays (DRM check — mandatory every batch)
- [ ] YouTube plays a 4K/HDR video
- [ ] Remote: all keys work (nav, back, home, volume, power)
- [ ] Sound output normal (passthrough/ARC if used)
- [ ] CEC: TV on/off via box, one-key-play, input switch
- [ ] Casting: phone casts to box
- [ ] Reboot completes cleanly to launcher (do this at least every 2 batches)

Any failure → `bash scripts/revert-batch.sh <batch packages>` — whole batch, no debugging forward.
