# Baseline metrics — Phase 0

Run: `device/runs/2026-10-25-143813` (captured 2026-10-25, BOX_IP=192.168.60.253)

Device: Homatics Box R 4K Plus (ro.product.device: YYJ), Android 14.

## Boot measurements (manual, power-cycle)

| Measurement                      | Result      |
|----------------------------------|-------------|
| Power-on → interactive home, run 1 | < 30 s     |
| Power-on → interactive home, run 2 | < 30 s     |
| Launcher cold start               | < 2 s      |

Exact timings not taken; both boots consistently under 30 s. Re-measure after
debloat for before/after comparison (Phase 5).

## Idle snapshot (from baseline dumps)

- Total RAM: 3,497,520K (~3.34 GB); Free RAM: 1,613,396K
- Processes (ps -A): 366
- Packages: 150 total / 138 system / 12 user / 1 disabled (stock)
- Full dumps (meminfo, alarm, jobscheduler, settings, CEC, feature flags,
  screenshot, bugreport.zip) in the run directory above.

Notes:
- `feature-flags.txt` initially failed: baseline.sh invoked `device_config`
  without a subcommand (help text only). Fixed to `device_config list` and
  recaptured (1524 flags) in the same run directory.
