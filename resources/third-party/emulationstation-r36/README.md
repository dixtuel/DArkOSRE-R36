# R36 EmulationStation source candidate

This directory contains a source-pinned EmulationStation-FCAMOD build recipe and the one R36-specific source override that is present in this checkout. It does not contain a firmware image, does not install a binary, and does not publish an OTA.

The candidate base is FCAMOD branch `351v` at `74498be31cd016af6a42d00310f876d7256eff52` (tree observed 2026-10-03). Vanilla dArkOS's `build_emulationstation.sh` selects `351v` for its RG351MP target but clones a moving branch name at build time. `scripts/fetch-pinned-source.sh` pins this snapshot and initializes its recorded submodule. This is a reproducible source starting point, not proof that the existing R36 frontend was built from it. The physical device binary and firmware-source overlay have different SHA-256 values, and the original R36 frontend source/build revision is unavailable.

## Source feature checks

The target branch already contains the relevant portable UI/source behavior. The individual feature commits named in vanilla notes are not all ancestors by their original commit IDs; upstream merged equivalent code under these full merge IDs:

| Feature | Source evidence at pinned `351v` | Merge/lineage evidence |
|---|---|---|
| Wi-Fi status indicator toggle | `es-app/src/guis/GuiMenu.cpp:1311-1319` exposes `SHOW NETWORK ICON`; `es-core/src/Settings.cpp:108` defaults `ShowNetworkIndicator` to true; `es-core/src/components/ControllerActivityComponent.cpp:395-412` gets an IPv4 address and gates the status on that setting. | Indicator commit `44c43bae0c36629ed6ee552c3ca0ad607cb4fba1` is reachable; original UI commit `971087a7eaa853d7019ca55033f9397a15bee19` is not an ancestor, but merge `287070bd0246b7228786c18ba4c7f357753bab78` is and the code is present in the pinned files. |
| TheGamesDB user key | `es-app/src/guis/GuiMenu.cpp:248-253` adds `API KEY`; `es-app/src/scrapers/GamesDBJSONScraperResources.cpp:56-59` reads `GamesDBApiKey` before the build fallback. | Original commit `a1c5ef5d1fb1f64db03f55e7dd4c7f0a2177edf6` is not an ancestor; merge `558fbfbb93726e7c83579f037ab8a96a651b5095` is an ancestor and the implementation is present in both pinned files. No API credential is set or stored by this build recipe. |
| GuiTools menu labels | `es-app/src/guis/GuiTools.cpp:43-46,106,116` constructs `NameResolver` and resolves folder/script labels; `es-core/src/utils/NameResolver.cpp:127-169` uses `.name`, `# NAME:`, then filename fallback. | Initial implementation `656853ab0de1326468ccdf4d7b18397349e1f867` is reachable. Later commit `d610557c538b0cb12766771c64c92db3dda64e80` is not an ancestor, but the four resulting files (`GuiTools.cpp/.h`, `NameResolver.cpp/.h`) have identical content on the inspected `351v` and `master` tips; do not count this as a code gap. |
| Battery icon refresh after theme change | `es-core/src/components/ControllerActivityComponent.cpp:389-392` clears cached theme texture/image and resets level. | `c728158106409913a9e406e15b17ddf10e5403a0` is reachable from `351v` and predates the 2026-03-10 R36 source release. |

The Wi-Fi implementation in the pinned branch queries `wlan0`. This candidate keeps vanilla behavior unchanged; no interface-discovery change is included without device evidence. Polish/Italian locale changes and BatteryPlus integration are not part of this build candidate. The `351v` language-selector block is commented out, and the R36 image has its own battery subsystem.

## R36-specific override

`patches/0001-r36-volume-control.patch` replaces only `es-core/src/VolumeControl.cpp` with the exact source retained at `overrides/VolumeControl.cpp` and in the firmware overlay at `resources/github/EmulationStation-fcamod/VolumeControl.cpp` (SHA-256 `763dd7c2608799b437a5a18ba2c5ec3005e892a46b032e3b8e5f99f63359252a`). It selects ALSA element `Playback` on card `rockchiprk817co` and contains the R36-specific nonlinear volume read/write mapping. Replacing this source with the generic upstream file would lose the R36 mixer selection and level mapping.

The exact retained override has two whitespace diagnostics under `git diff --check` (a trailing space on the mixer-card line and indentation before a tab in an error return). The patch deliberately preserves the source byte-for-byte; the preparation script verifies its SHA-256 and does not rewrite it to silence style diagnostics.

## Prepare and build

From the firmware fork root:

```sh
resources/third-party/emulationstation-r36/scripts/fetch-pinned-source.sh /tmp/EmulationStation-fcamod-r36
resources/third-party/emulationstation-r36/scripts/apply-r36-overrides.sh /tmp/EmulationStation-fcamod-r36
resources/third-party/emulationstation-r36/scripts/build-r36-candidate.sh /tmp/EmulationStation-fcamod-r36
```

The preparation script refuses another FCAMOD revision, checks that the Wi-Fi toggle and user API-key behavior are already in the pinned source, and applies only the R36 volume override. The build script defines an empty `GAMESDB_APIKEY` macro so the user-entered setting is compiled without embedding any credential. It does not set ScreenScraper credentials.

The build needs the FCAMOD dependencies listed in its upstream `README.md`: CMake, C++ compiler, SDL2, SDL2_mixer, FreeImage, FreeType, cURL, VLC, RapidJSON, Boost, Eigen, ALSA, OpenGLES and the pinned submodules. Do not install FCAMOD's bundled Debian 10 Mali `.deb` files on R36S. Use an AArch64 Debian 13 build host or a matching AArch64 cross compiler and R36 sysroot. Set `CMAKE_TOOLCHAIN_FILE`, `CMAKE_SYSROOT`, `CC`, and `CXX` as appropriate for a cross build. The upstream CMake sets the executable output directory to the source tree, so the candidate appears as `FCAMOD_SOURCE/emulationstation`; the script refuses to overwrite an existing file there and never copies the result into the firmware overlay or device.

The current review host is x86_64, has no AArch64 cross compiler or R36 sysroot, and lacks SDL2_mixer pkg-config metadata. The actual CMake build was therefore not run. Until compiler, sysroot and dependency versions are pinned, this is a source-pinned build procedure rather than a bit-for-bit reproducible binary build. Record those toolchain inputs before treating an output as a release candidate.

## Verification gates before any future installation

1. Confirm the source checkout is exactly the pinned commit and submodule gitlinks.
2. Apply the override and compare it byte-for-byte with the retained R36 source file.
3. Build for AArch64 and inspect ELF machine, interpreter, linked libraries and resource layout.
4. Compare the candidate against the running device UI and current launcher/service integration. Test EmulationStation start/exit, Wi-Fi toggle/display, TheGamesDB on-screen key entry, tools menu, volume controls, theme reload, and both `/roms` and `/roms2` library views.
5. Only after those checks should a separate OTA review consider the candidate binary. This directory does not authorize or perform that installation.

## Provenance and license

- Source repository: <https://github.com/christianhaitian/EmulationStation-fcamod>
- Source ref: `351v` at `74498be31cd016af6a42d00310f876d7256eff52`.
- Feature references: `971087a7eaa853d7019ca55033f9397a15bee19`, merge `287070bd0246b7228786c18ba4c7f357753bab78`; `a1c5ef5d1fb1f64db03f55e7dd4c7f0a2177edf6`, merge `558fbfbb93726e7c83579f037ab8a96a651b5095`; `656853ab0de1326468ccdf4d7b18397349e1f867`; `d610557c538b0cb12766771c64c92db3dda64e80`; `c728158106409913a9e406e15b17ddf10e5403a0`.
- FCAMOD's root `LICENSE.md` at the pinned source states the MIT License. Its text is retained in `UPSTREAM-LICENSE-MIT.txt`. Submodules and bundled third-party dependencies have their own licenses; this source patchset does not redistribute their contents.
