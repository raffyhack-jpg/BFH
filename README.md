# BFH iPhone project — Pocket Front prototype

A native offline iPhone shooter prototype with original Battlefield Heroes
Royal and National base character meshes and textures. This remains a prototype;
it is not an identical or finished Battlefield Heroes remake. It is not
endorsed by EA. Reuse of original assets relies on the repository owner's stated
permission; the MIT license covers original code only.

## Included

- Native Swift/UIKit/SceneKit app for landscape iPhone, iOS 15+.
- Offline 8v8: one player and fifteen bots, three classes (Soldier, Gunner, Commando).
- Original Royal/National base models: 2,406 vertices and 2,286 triangles per
  faction, with original 1024px uniform textures. Original weighted skeletons and idle/run/fire/death/jump clips; weapon-specific poses are imported during preparation.
- Original heat map terrain, town buildings, trees, props and original object placements.
- Original v1.105 clothing catalog, meshes, texture layers, item icons and localized names.\n- Hero preview, faction/class selection, clothing categories, skin/hair palettes and saved loadouts.\n- Selectable original weapon models, two weapon slots, magazine counts, reloads and weapon animation poses.
- Original sky dome/sky texture, capture flags and flagpole geometry.
- Original Flash menu logo and scenic backdrop, imported without redrawing.
- Conquest: capture the map objectives, drain enemy tickets, respawn.
- Capture the Flag: defend/return flags and escort carriers; three captures wins;
  dropped flags return after eighteen seconds.
- Elimination: no respawn; eliminate the enemy squad.
- Rocket Control: capture and hold one objective for sixty cumulative seconds.
- Five minute match cap, results, pause/resume, health, score, kills/deaths.
- Class abilities: squad heal, temporary shield, dash.
- Bots select mode objectives, navigate using A*, check line of sight, strafe,
  retreat, heal at base, use abilities, and shoot with imperfect accuracy.

## Controls

Left stick moves relative to camera. Drag the right side to look, or hold and drag\nFIRE to aim and shoot with one thumb. JUMP jumps; SWAP changes equipped weapon;\nRELOAD reloads the magazine. ABILITY activates the class skill. The follow camera\nkeeps world up fixed and pulls in before obstructing scenery. Combat uses horizontal hitscan with modest
horizontal aim assistance. Pause opens Resume/New Match; backgrounding pauses.

## Build

On a Mac with Xcode installed and first-launch components ready:

```sh
bash scripts/prepare_original_assets.sh
bash scripts/check_animation.sh
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

GitHub Actions recovers the SHA-1 verified original 1.105 installer, converts
original scenery, wardrobe, icons, localized item names, weapons and motion clips, validates them, then builds on macOS.
Generated world assets are bundled in the IPA; they are not checked into Git.
The source archive is about 1.2 GB, so first preparation needs a network connection
and disk space. On macOS the preparation script installs innoextract through
Homebrew and uses a local Python virtual environment with NumPy and Pillow.

The manual `publish-ipa.yml` workflow publishes the IPA as a private prerelease
asset. Select Run workflow on main; download the IPA from Releases. Ordinary
builds still attempt an Actions artifact upload, which can fail when account
artifact storage is full. Such an upload failure does not demonstrate a build
failure; consult the asset and compile steps. Publishing has contents-write
permission only for its manually dispatched publishing job.

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

The procedural arena and box guns have been removed from normal gameplay.
`tools/original/convert_world.py` converts the map's original height field,
color tiles, object placement script, building/tree/prop meshes, six faction
weapons, flags and sky. Source entries are checked against ZIP CRCs and recorded
with SHA-256 provenance. Meshes use native interleaved geometry buffers; textures
are converted from DDS to PNG. The world is built during CI from verified source
rather than padding the IPA with unused archive data. The IPA verifier requires
all referenced geometry and textures to be present. Missing original world or
character data causes an explicit load failure instead of a primitive fallback.

Original buildings are placed at their original positions and rotations; hero
and camera heights follow the terrain. Bots use spatial collision lookup and
heap-based A* on the larger original map. Footprints are approximate rotated
bounds, not the original collision engine. Native checks require walkable
spawns and routes from both bases to every converted objective.

This is still incomplete: only one original map is converted. Playable vehicles,
aircraft, original weapon audio, complete animation/clothing coverage,
cosmetics/progression, faithful class abilities, network play, controller
support, accessibility and reproduction of every historical mode remain
unfinished. Map import and a successful build do not establish device visual
fidelity, bot balance or a polished recreation. No iPhone playtest has happened.

## Source map

- App/Game.swift: gameplay, mode rules, bot navigation (Foundation only).
- App/App.swift: app lifecycle, touch controls, menus, SceneKit renderer.
- App/OriginalWorld.swift: original scenery, weapon loading, terrain sampling.
- tools/original: verified archive recovery, original mesh reader, conversion.
- scripts/prepare_original_assets.sh: reproducible original-world preparation.
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

## Customization fidelity

The wardrobe reads the original `items.xml`, `defaultcustomization.xml`, `colors.xml`,
`weapons.xml`, CON geometry/texture definitions, item icons and English localization
from the preserved 1.105 installer. It preserves original item IDs, faction/class
restrictions, clothing slots and layer order. The UI is a native touch adaptation;
it does not reproduce the complete original Flash interface. Asset definitions
with unresolved or unusable render geometry are reported in generated provenance
instead of being replaced with invented art. This source archive does not establish
that every item added to the live game after this client revision is included.

Weapon models, magazines, reload durations and animation groups come from the
original definitions. Damage/range are still prototype values, projectile behavior
and abilities are incomplete, and character texture composition needs device QA.
The game remains an offline prototype with one map; it is not a complete identical
recreation of every original mode, vehicle, unlock, audio cue or online feature.
