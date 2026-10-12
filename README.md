# Pocket Front — iPhone prototype

An original offline cartoon military shooter inspired by the broad appeal of
classic casual team games. This is **a first prototype**, not an identical
Battlefield Heroes remake, not a finished production game, and not affiliated
with EA. It now includes original installer artwork extracted from an archived version
1.105 installer, under the permission stated by the user. Game characters, maps,
weapons, and audio are still procedural/placeholders. See `Assets/provenance.json`.

## Included

- Native Swift/UIKit/SceneKit app for landscape iPhone, iOS 15+.
- One original arena with cover, buildings, trees, and simple procedural characters.
- Offline 6v6: one player and eleven bots; three classes with distinct health,
  movement, weapons, and abilities (squad heal, temporary shield, dash).
- Conquest: capture three points, drain enemy tickets, respawn.
- Capture the Flag: defend/return your flag, escort carriers, win at three captures;
  dropped flags auto-return after eighteen seconds.
- Elimination: no respawn, win when the enemy squad is eliminated.
- Rocket Control: capture and hold one objective for sixty cumulative seconds.
- Five minute cap, results, pause/resume, health, scores, kills/deaths, cooldowns.
- Bots choose mode objectives, distribute attackers across points, escort/defend,
  navigate a grid using A*, test line of sight, strafe, retreat, heal at their base,
  use abilities, and fire with imperfect accuracy.

## Controls

Left stick moves relative to camera; right stick turns camera; FIRE shoots;
ABILITY activates your class skill. Combat uses horizontal hitscan with modest
horizontal aim assistance. Drag the right stick to align with enemies. The pause
button opens Resume/New Match. The app pauses when backgrounded.

## Build the unsigned IPA

On a Mac with Xcode installed and its first-launch components ready:

```sh
bash scripts/build_unsigned.sh
```

This generates the Xcode project, compiles and runs deterministic game-core
checks with Swift, builds the real ARM64 iPhone executable without signing,
and packages `build/PocketFront-unsigned.ipa`. It verifies that a compiled Mach-O
executable exists in `Payload/PocketFront.app` and no signature is present.
It never substitutes a source ZIP or simulator app for an IPA.

For GitHub, put **the contents of this directory** at your selected repository's
root, including `.github/workflows/ios.yml`. Commit to main or run
**Actions → Build unsigned iPhone IPA → Run workflow**. Download the
`PocketFront-unsigned` artifact after the build succeeds. The workflow uses a
macOS runner; private repositories may consume your Actions minutes.

An unsigned IPA requires signing with your own identity/provisioning before it
can run on a standard iPhone. For normal development, open
`PocketFront.xcodeproj`, select your personal team in Signing & Capabilities,
choose a unique bundle identifier, then build to your device in Xcode.

## Verification status

Created on Linux, which has neither Swift nor Xcode. The project generator,
Info.plist, scheme XML, workflow syntax, shell syntax, project file references,
and ZIP packaging were checked locally. **Swift compilation, simulation checks,
3D rendering, touch usability, frame rate, device installation, and the actual
IPA build have not been run.** The workflow must succeed before any build is
represented as usable. `Tests/main.swift` covers objective scoring, ticket drain,
kill credit, respawn, flag scoring, elimination/rocket victory, obstacle routing,
pause behavior, bot combat and completion in each implemented mode.

## What remains for a full game

Licensed/original production characters, rigging and animation, audio, additional
maps, vehicles and aircraft, weapon inventory and tuning, deeper class abilities,
progression/customization, onboarding, accessibility, controller support,
performance/thermal profiling, richer navigation/cover tactics, device playtests,
and balance iterations. There is no networking, account system, monetization,
vehicle combat or reproduction of every historical Battlefield Heroes mode.
Bot fun and difficulty have not been playtested. All characters are simple
procedural shapes and the map is intentionally compact.

## Source map

- `App/Game.swift`: deterministic gameplay and navigation; Foundation only.
- `App/App.swift`: app lifecycle, touch controls, menus, 3D view and effects.
- `Tests/main.swift`: standalone Swift core checks, run before every CI build.
- `scripts/create_project.py`: reproducible Xcode project generation.
- `scripts/build_unsigned.sh`: macOS tests/build/package.
- `scripts/verify_ipa.py`: compiled executable/IPA structural validation.

Original source code in this package is licensed under the MIT License.
The original Battlefield Heroes artwork is excluded from that license and
retains its original ownership; inclusion relies on the user’s stated permission.

## Original assets recovery

The Internet Archive item `battlefield-heroes-setup` contains a 1,203,733,068-byte
RAR installer archive. Its installer identifies version 1.105 and lists the
original map and object ZIP archives. Its first data segment and installer
metadata were inspected; `app/bfh.bmp` was successfully extracted and converted
losslessly to PNG. It is shown alongside the prototype menu. This installer is
a third-party preserved package; identity with EA release hashes was not checked.
The full client has not been downloaded, and original 3D models/animations have
not been converted or integrated. The preserved installer file list is included
as `Assets/installer-file-list.txt`.


## Original characters integrated

The complete preserved installer archive was downloaded and its Internet Archive
SHA-1 was verified (`7b77439053f6e79ebf5a9020b22aff85e49195e6`). Original Royal
and National base character geometry (2,406 vertices / 2,286 triangles each) and
1024px uniform textures were converted to COLLADA/PNG and connected to the native
character renderer. They use static bind poses; original skeletal animation,
cosmetics, original weapons and maps remain unfinished. Provenance is recorded in
`Assets/Characters/provenance.json`. The asset validator checks SceneKit loading
and geometry on macOS CI. Device appearance and controls still need playtesting.

The first macOS CI build compiled successfully, passed all game-core checks,
and verified a real unsigned ARM64 IPA. Artifact upload failed because the
account's Actions storage quota was full. Private-release delivery requires an
approved change granting the publishing job repository contents-write access.
