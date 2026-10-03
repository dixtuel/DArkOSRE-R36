# Adaptation implementation and remaining gates — 2026-10-03

This records implementation status for the R36S-applicable changes selected in the vanilla audit. Source code and the device OTA are separate: an item in the firmware source does not reach the device until an OTA contains it and that OTA completes.

## Implemented for firmware source and follow-up OTA

| Item | R36 implementation | `/roms` / `/roms2` behavior | Verification status |
|---|---|---|---|
| Auto-suspend input monitoring | OTA installs maintained `auto_suspend.py`, which uses `evdev` discovery rather than the older `inputs` polling path. | Does not read ROM directories. | Installed file is root-owned executable and Python can import `evdev`. The device has no `.TIMEOUT` setting, so the autosuspend daemon is not enabled; no behavior was forced on. |
| Themes on second card | OTA creates `/home/ark/.emulationstation/themes -> /roms2/themes` only when the path is absent or already a symlink, and only when `/roms2/themes` exists. A real directory is retained. | Deliberately targets the user's second-card theme directory. | Verified after reboot; symlink resolves to the existing `/roms2/themes` directory. |
| Atari 800/XEGS defaults | OTA removes only the known `--config ... retroarch_A800.cfg` and `retroarch_XEGS.cfg` command overrides in those two XML system blocks. | Checks the full `<path>` list before and after, so active `/roms2` entries remain intact. | Verified after reboot: the XML parses, both commands use the default core, and game paths remain `/roms2`. |
| Backup / restore | OTA updates the R36 backup and restore scripts. Backup uses a temporary archive and replaces the prior archive only after `tar` succeeds; includes `filebrowser.db` if present. Restore pauses NetworkManager and stops FileBrowser while restoring. | Existing R36 behavior writes under `/roms/backup` and copies the successful archive to `/roms2/backup`; restore accepts either card. | Both scripts pass `bash -n` and are installed root-owned executable. Interactive backup and restore were not run to avoid replacing the user's stored backup or settings. |
| Daphne | OTA installs the maintained R36 launcher version; it retains `-texturestream` and omits `-useoverlaysb 2`. | The launcher derives its Daphne folder from the selected ROM path. | Installed hash matches the maintained R36 source. Game-specific launch remains to be tested with a Daphne title. |
| Singe and ZLua | New R36 launcher selects `/roms` or `/roms2` from the EmulationStation shortcut, points both Hypseus shared links at the selected `alg` tree, checks the frame file, and launches either `.singe` or ZLua `.zip`. | The card switch scripts no longer rewrite Singe source text globally. OTA removes just those two obsolete lines and verifies the rest of both switch scripts is unchanged. | Installed as root-owned executable; switch rewrites are absent and ROM2 config stayed intact. `/roms2/alg` has only its scanner, so gameplay remains untested. |

The OTA archive itself contains five scripts only. The updater backs up every file it may replace or edit—including the XML and both SD switchers—to an owner/mode-preserving tar on the active ROM card. Download checksum, ZIP structure, base version, chipset, writable rollback destination, free temporary space, active ROM-root paths, and unchanged SD-switcher content are checked before the completion marker/reboot. The public release workflow and archive validation passed.

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
- OTA `10032026-r1` installed through `/opt/system/Update.sh`; the device rebooted and returned to active EmulationStation with `.VERSION=10032026-r1` and its completion marker present.
- Both ROM cards remained mounted after reboot, all EmulationStation game `<path>` values remained on `/roms2`, Atari XML parsed, the theme symlink resolved, and the rollback tar SHA-256 passed. The archive contains the original XML, both switchers, and all five installed scripts.
- `/roms2/alg` contains the scanner but no Singe game payload. No full game launch, interactive backup, or restore test was performed.
- The previous read-only `apt-get -s upgrade` attempt timed out; it made no package changes.
- `systemd-remount-fs.service` reported `mount: /: mount point not mounted or bad option` during boot. This OTA contains no `/etc/fstab`, rootfs mount, kernel, or boot-partition changes; investigate this separately before any Debian/base-system update.
- The old updater printed an invalid-argument error when setting brightness to hard-coded 255; this device's maximum is 160. The update fork's raw-main updater now reads `max_brightness` before raising brightness. The OTA itself completed successfully.

## Test and release boundary

Shell syntax, archive/checksum/path checks, installation, reboot, EmulationStation, Python import, and ROM2 preservation are verified. Gameplay remains unverified for Singe/ZLua and Daphne, and interactive backup/restore behavior was not exercised. The missing Singe game files prevent a Singe gameplay claim. The root remount service failure and the excluded Debian/graphics/PortMaster/DSperate items remain separate work.
