# scripts/

Build and test drivers. Not implemented in Phase 1 (ISO assembly is
Phase 4):

- `build_iso.sh` — drives `live-build` using `base/live-build/` config to
  produce the installable ISO.
- `test_qemu.sh` — boots the built ISO under QEMU/OVMF for the Phase 4
  acceptance test (ISO boots → installer completes → installed system
  boots to Plasma login → `vita update` runs end to end → pre-update
  snapshot boots from GRUB).
