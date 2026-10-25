# Home Assistant integration (future)

Box works with HA's Android TV (ADB) integration — same channel this kit uses.

Prerequisites (do during Phase 0, not later):
- Static IP for the box (DHCP reservation on the router)
- Ethernet preferred
- "Always allow connections from this device" checked at pairing
- Wake-from-standby test: run scripts/wake-test.sh; if the box drops network
  in standby, HA power-on will need CEC or an always-on approach

HA setup later: Settings → Devices & Services → Add Integration →
Android TV → enter box IP. Approve the prompt on the TV.

Consequences for this kit:
- Network debugging stays ON permanently (update durability phase accordingly;
  only disable if the box leaves the trusted LAN)
- scripts/backup.sh keeps backups of everything HA needs to re-approve
- Do not disable any component that ADB debugging depends on (already enforced
  by protected.txt rules)
