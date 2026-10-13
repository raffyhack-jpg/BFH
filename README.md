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
- Original v1.105 clothing catalog, meshes, texture layers, item icons and localized names.
- Hero preview, faction/class selection, clothing categories, skin/hair palettes and saved loadouts.
- Selectable original weapon models, two weapon slots, magazine counts, reloads and weapon animation poses.
- Original sky dome/sky texture, capture flags and flagpole geometry.
- Original Flash menu parchment, painted red navigation, olive panels, equipment frames, Play Now button, currency icons, animated faction HUD flags and scenic backdrop, imported without redrawing. Original artwork fills the landscape screen; controls use phone-point layouts with 44-point menu hit targets. Tabs reuse one menu, inventory controller and animated hero scene.
- Conquest: capture the map objectives, drain enemy tickets, respawn.
- Capture the Flag: defend/return flags and escort carriers; three captures wins;
  dropped flags return after eighteen seconds.
- Elimination: no respawn; eliminate the enemy squad.
- Rocket Control: capture and hold one objective for sixty cumulative seconds.
- Visible 15-minute round clock, explicit objective/time-limit result reasons, pause/resume, health, score, kills/deaths.
- Class abilities: squad heal, temporary shield, dash.
- Bots select mode objectives, navigate using A*, check line of sight, strafe,
  retreat, heal at base, use abilities, and shoot with imperfect accuracy. Flag carriers
  follow their return route during combat; retrieval squads split from escorts.
  Melee bots close to striking distance and select weapons for their target range.
  Movement uses a single speed budget per frame.

## Controls

Left stick moves relative to camera. Drag the right side to look, or hold and drag
FIRE to aim and shoot with one thumb. JUMP is on the right; tap either enlarged bottom weapon icon to select that slot;
RELOAD reloads the magazine. The third bottom icon activates the class skill. Blue ALLY and red ENEMY nameplates identify visible characters. The follow camera
keeps world up fixed and pulls in before obstructing scenery. Player shots follow the crosshair in 3D and intersect airborne character capsules,
terrain and scenery; the shoulder camera converges on characters under the reticle. Pause opens Resume/New Match; backgrounding pauses.

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

Successful builds on main publish their verified unsigned IPA and asset previews
as prerelease assets. Download the newest build from Releases. This avoids
Actions artifact storage limits. The manual `publish-ipa.yml` workflow is also
available. Both publishing jobs use contents-write permission with checkout
credential persistence disabled.

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
Native iPhone simulator screen captures are published with current builds. There has been no controlled physical-device touch playtest, frame-rate/thermal profile,
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

## Combat UI and offline career

The native HUD now has outlined floating damage values, hit flashes/sparks,
colored ticket banners, objective badges, health/ammo meters, an XP bar,
elimination/capture messages and level-up feedback. The main menu presents the
original animated hero next to equipment and career controls. These are native
recreations of the visual language, not a pixel-identical port of the Flash HUD.
The original UI converter exports matching HUD/menu artwork and any native
TTF/OTF fonts available in the client, with source hashes; unsupported packed
Flash/bitmap fonts still use a native font fallback.

Careers persist independently for each faction/class. XP is earned from actual
damage (excluding overkill and invulnerable hits), eliminations and objectives.
Levels use the historical 1–30 cumulative XP table documented at
https://bfh-info.cs-heroes.cz/en/game/level/ . The starting Hero Point is assigned
to the class skill; even levels grant another point. The implemented prototype
class skill can be upgraded through five ranks. This is not the full original
ability tree or post-level-30 rank system.

The wardrobe is also a local shop: defaults and existing saved equipment are
grandfathered as owned, while new purchases check ownership, source level
requirements and available currency before equipping. Explicit VP/Battlefunds
price fields are preserved when present. Missing prices use clearly labeled
local fallback prices (250 VP for clothes, 500 VP for weapons). Match VP payouts
and the three starter missions are offline balancing choices; they are not
claimed as original historical commerce rules. Battlefunds have no real-money
top-up in this offline app. Rentals, historical store promotions, cash payments
and the full original mission catalog remain unfinished.

Career saves, purchases, Hero Point spending and repeated match reward claims
are covered by game-core checks. A successful native build and device visual
playtest are still required before calling this release verified or polished.

## Interface reference and visual checks

See [original interface references](docs/original-interface-reference.md) for the inspected screenshots/footage, asset mapping and fidelity gaps. `bash scripts/check_interface.sh` captures the running native menu, store, abilities and gameplay on an installed iPhone simulator.

The mobile navigation check cycles inventory, weapons, store and abilities and asserts that the menu, hero and SceneKit scene retain their identity. It verifies full-screen paper bounds and menu targets at least 44 points high. All six original default kits are checked for explicit `cit_hands` geometry. Bot sensing is staggered, unchanged paths are reused, path jobs are limited per frame, player aiming rays run only for shots, and the covered game scene stops rendering in menus. Physical-device frame-rate and thermal behavior still require playtesting.
