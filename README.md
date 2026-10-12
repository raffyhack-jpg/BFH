# BFH iPhone project — Pocket Front prototype

A native offline iPhone shooter prototype with original Battlefield Heroes
Royal and National base character meshes and textures. This remains a prototype;
it is not an identical or finished Battlefield Heroes remake. It is not
endorsed by EA. Reuse of original assets relies on the repository owner's stated
permission; the MIT license covers original code only.

## Included

- Native Swift/UIKit/SceneKit app for landscape iPhone, iOS 15+.
- Offline 6v6: one player and eleven bots, three classes (Soldier, Heavy, Scout).
- Original Royal/National base models: 2,406 vertices and 2,286 triangles per
  faction, with original 1024px uniform textures. Original weighted skeletons and idle/run/fire/death clips.
- One compact original arena with cover, buildings, trees, and simple weapons.
- Conquest: capture three points, drain enemy tickets, respawn.
- Capture the Flag: defend/return flags and escort carriers; three captures wins;
  dropped flags return after eighteen seconds.
- Elimination: no respawn; eliminate the enemy squad.
- Rocket Control: capture and hold one objective for sixty cumulative seconds.
- Five minute match cap, results, pause/resume, health, score, kills/deaths.
- Class abilities: squad heal, temporary shield, dash.
- Bots select mode objectives, navigate using A*, check line of sight, strafe,
  retreat, heal at base, use abilities, and shoot with imperfect accuracy.

## Controls

Left stick moves relative to camera; right stick turns camera; FIRE shoots;
ABILITY activates the class skill. Combat uses horizontal hitscan with modest
horizontal aim assistance. Pause opens Resume/New Match; backgrounding pauses.

## Build

On a Mac with Xcode installed and first-launch components ready:

```sh
bash scripts/build_unsigned.sh
```

This generates the Xcode project, runs game-core checks, builds a real ARM64
iphoneos executable without signing, and produces
`build/PocketFront-unsigned.ipa`. It checks the Mach-O executable and absence of
a code signature. The unsigned IPA must be signed with an appropriate identity
and provisioning profile before it runs on a standard iPhone.

For ordinary device development, open `PocketFront.xcodeproj`, choose a personal
team in Signing & Capabilities, set a unique bundle identifier, and build to your
connected device in Xcode.

GitHub Actions builds on macOS when pushing main or codex/pocketfront-ios. The
workflow validates SceneKit assets, runs core checks, compiles, and attempts to
upload `PocketFront-unsigned`. The account's Actions artifact storage quota was
full during the initial build. A private-release upload needs an approved change
to give the publishing job repository contents-write permission. Private
repository runs consume Actions minutes.

## Original assets

The complete preserved v1.105 installer was retrieved from
https://archive.org/details/battlefield-heroes-setup and verified against its
published SHA-1: `7b77439053f6e79ebf5a9020b22aff85e49195e6`.
This confirms the archived download, not independent identity against EA hashes.
Original base meshes and uniform textures were extracted from Soldiers_client.zip
and converted to COLLADA/PNG plus weighted skeleton/clip data using the MIT-licensed mesh reader from
https://github.com/marekzajac97/bf2-blender. The conversion changes coordinate
handedness and UV convention, and preserves original two-bone vertex weights, inverse-bind transforms, and decoded motion clips in companion rig files. Original
installer artwork is also included. Provenance is recorded in Assets.

## Validation and limits

The first macOS CI build passed all core checks, compiled with Xcode 16.4, and
verified an unsigned ARM64 IPA. Core checks cover objective scoring, ticket drain,
kill credit, respawn, flags, victory, obstacle routing, pause, and bot combat/match
completion in each implemented mode. The original characters were integrated
subsequently; their SceneKit validation and rebuild status are reported in CI.
There has been no iPhone installation, touch playtest, frame-rate/thermal profile,
or bot difficulty/balance playtest. No build should be described as a polished
finished game.

Original map reconstruction, vehicles/aircraft, original weapon geometry/audio,
complete original animation coverage, cosmetics/progression, faithful class abilities,
network play, controller support, accessibility, and reproduction of all
historical modes remain unfinished. Original characters now animate using original clips;
prototype maps, weapons, mechanics, and class names still differ from BFH.

## Source map

- App/Game.swift: gameplay, mode rules, bot navigation (Foundation only).
- App/App.swift: app lifecycle, touch controls, menus, SceneKit renderer.
- Assets/Characters: converted original base characters and provenance.
- Tests/main.swift: deterministic simulation checks.
- scripts/check_assets.swift: native SceneKit import/geometry validation.
- scripts/create_project.py: reproducible Xcode project generation.
- scripts/build_unsigned.sh: macOS tests/build/package.
- scripts/verify_ipa.py: Mach-O and IPA structure checks.

Original code: MIT. EA assets retain their original ownership and are excluded
from the MIT license.

## Skeletal animation update

`App/Animation.swift` builds GPU-skinned character geometry from the original
vertex weights and inverse-bind matrices, uses the 74-bone original skeletons,
and decodes original idle, running, firing, and death animation tracks. Firing layers
over locomotion on the upper body. Royal tonic animation is included when
available; the National variant currently has no converted ability clip. Pose
transitions blend, root translation is removed so gameplay movement controls
position, and death uses the original Common death clip before respawning resets playback. A mapping translates
the legacy base-mesh bone layout to the current skeleton. This requires visual
device validation; original skeletal clips do not imply exact recreation of the
full original animation state machine or ragdoll behavior. The native asset
checks compile the animator, validate skin data, and exercise run/fire/death/reset.
