# Adaptation implementation and remaining gates — 2026-10-03

This records implementation status for the R36S-applicable changes selected in the vanilla audit. Source code and the device OTA are separate: an item in the firmware source does not reach the device until an OTA contains it and that OTA completes.

## Implemented for firmware source and follow-up OTA

| Item | R36 implementation | `/roms` / `/roms2` behavior | Verification status |
|---|---|---|---|
| Auto-suspend input monitoring | OTA installs maintained `auto_suspend.py`, which uses `evdev` device discovery rather than the older `inputs` polling path. | Does not read ROM directories. | Source is the same version already observed on the device; runtime import/service smoke check still required after OTA. |
| Themes on second card | OTA creates `/home/ark/.emulationstation/themes -> /roms2/themes` only when the path is absent or already a symlink, and only when `/roms2/themes` exists. A real directory is retained. | Deliberately targets the user's second-card theme directory. | Device already has the intended symlink and directory. Verify it still resolves after reboot. |
| Atari 800/XEGS defaults | OTA removes only the known `--config ... retroarch_A800.cfg` and `retroarch_XEGS.cfg` command overrides in those two XML system blocks. | Checks the full `<path>` list before and after, so active `/roms2` entries remain intact. | Device current config already has these overrides removed. Verify XML parse and ROM roots after OTA. |
| Backup / restore | OTA updates the R36 backup and restore scripts. Backup uses a temporary archive and replaces the prior archive only after `tar` succeeds; includes `filebrowser.db` if present. Restore pauses NetworkManager and stops FileBrowser while restoring. | Existing R36 behavior writes under `/roms/backup` and copies the successful archive to `/roms2/backup`; restore accepts either card. | Static shell syntax checked. Must test backup creation and restore-selection without restoring user settings; no backup/restore was run yet. |
| Daphne | OTA installs the maintained R36 launcher version; it retains `-texturestream` and omits `-useoverlaysb 2`. | The launcher derives its Daphne folder from the selected ROM path. | Source/device hash had already matched. Game-specific launch remains to be tested with a Daphne title. |
| Singe and ZLua | New R36 launcher selects `/roms` or `/roms2` from the EmulationStation shortcut, points both Hypseus shared links at the selected `alg` tree, checks the frame file, and launches either `.singe` or ZLua `.zip`. | The card switch scripts no longer rewrite Singe source text globally. OTA removes just those two obsolete lines and verifies the rest of both switch scripts is unchanged. | Shell syntax checked. `/roms2/alg` currently contains only its scanner; there is no installed Singe title for a gameplay test. |

The OTA archive itself contains five scripts only. The updater backs up every file it may replace or edit—including the XML and both SD switchers—to an owner/mode-preserving tar on the active ROM card. Download checksum, ZIP structure, base version, chipset, writable rollback destination, free temporary space, active ROM-root paths, and unchanged SD-switcher content are checked before the completion marker/reboot. The public release must be created only from the validated source commit.

## Reviewed but intentionally excluded from this OTA

| Vanilla change | Why it is not copied as-is | Next evidence needed |
|---|---|---|
| RK3326 video preview/screensaver graphics fix (`4837de95426d2390f0ac2b28c87e8d29973ce04e`) | Vanilla changes its image-builder's Mali symlink aliases and scopes Vulkan repair to RK3566. Those build scripts do not exist in the R36 firmware fork; the live R36 G31 `libOpenCL.so -> libMali.so` link is part of its installed GPU stack. Removing it through OTA without a preview/screensaver test could break other consumers. | Reproduce the actual preview/screensaver failure on R36S, trace the consumer and G31 library dependencies, then test a reversible device-specific change. |
| PortMaster legacy FFmpeg/compatibility libraries | Vanilla's newest commit changes package URLs. The staged multi-library set only passed loader resolution; it has not passed actual PortMaster game, audio/video, ABI, and dependency coverage on the R36S. A previous R36 update installed an incomplete `libavcodec58` set. | Produce a complete, licensed two-ABI inventory and verify with representative PortMaster titles before a dedicated rollback-capable OTA. |
| Debian Trixie 13.6 | Vanilla runs an unpinned broad `apt upgrade`; that is not a fixed package payload and can alter the R36 kernel-adjacent stack. The device's APT simulation previously timed out; no transaction plan was obtained. | Resolve why APT simulation stalls, capture a package transaction and rollback plan, then test as a separate maintenance update. No APT package was changed by this adaptation. |
| DSperate | This adds an optional Nintendo DS emulator beside R36 Drastic/Advanced Drastic; it is not an R36 bug fix. The upstream launcher/config set and GPL-3 source/build chain require a separate build, controller, save-path, BIOS, and game test. | Treat as a separate optional emulator project; do not imply it improves DS performance until measured on-device. |
| Vanilla EmulationStation and wholesale emulator/core updates | R36 OTA `10032026` already carries the selected RK3326 emulator/core artifacts. Replacing ES config or binaries wholesale would overwrite R36 input/device and `/roms2` adaptations. Existing loader/version checks are not gameplay checks. | Test actual games, controls, sound, saves, and stability per emulator before further updates. |

## Device snapshot before `10032026-r1`

- Target reported dArkOSRE-R36 `.VERSION=10032026`, kernel `4.4.189`, Debian 13.3.
- Both `/roms` (main SD) and `/roms2` (second SD) are mounted; EmulationStation paths point to `/roms2`. `/roms2` has about 9.4 GiB free at the snapshot.
- `/home/ark/.emulationstation/themes` already resolves to `/roms2/themes`.
- EmulationStation was running when checked. `/roms2/alg` contains the scanner but no game payload. No live update was applied during the read-only inspection.
- The previous read-only `apt-get -s upgrade` attempt timed out; it made no package changes.

## Test and release boundary

Passing shell syntax, archive/checksum/path checks, and updater guard tests demonstrates package integrity, not complete gameplay compatibility. The OTA cannot be described as fully device-tested until it has installed, rebooted to EmulationStation, preserved the selected `/roms2` paths, passed Python/dependency and backup smoke checks, and had at least one representative target game tested for each changed launcher. The current lack of Singe game files prevents a Singe gameplay claim.
