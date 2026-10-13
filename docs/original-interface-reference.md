# Original interface references

This reconstruction uses the recovered 1.105 client sprites, not artwork generated to resemble the game. Screen layout is adapted to a landscape iPhone; it is not a port of the original Flash runtime or Refractor renderer.

## References inspected

- Original UI designer Andreas Lanjerud: https://helloandy.se/post/battlefield-heroes/ and the `bfh-menus.jpg` image on that page. Reference: parchment, painted red navigation, black submenu, selected yellow labels, olive panel headings, HP/VP/BF status strip, hero preview, equipment slots.
- Original gameplay screenshot: https://images.cgames.de/images/gamestar/287/battlefield-heroes_2290509.jpg . Reference: animated opposing faction flags, white outlined ticket counts, portrait XP ring, blue health cross, gold ammunition icon, small equipment icons and white damage numbers.
- Original launch trailer preserved at https://www.moddb.com/games/battlefield-heroes/videos/battlefield-heros-launch-trailer . Downloaded footage and inspected frames: uniform variations, round yellow Play Now button, painted menus, bright blue sky, green vegetation, simplified shaded surfaces. The copy ends before all advertised frames decode.
- EA/DICE SIGGRAPH 2010 rendering presentation: https://stylized.realtimerendering.com/ . Primary source for the original rendering approach. The SceneKit adaptation does not reproduce the original shaders.

The Dribbble UI redesign was excluded as a reference for the original UI. The Jackfrags YouTube video was located, but playable media could not be retrieved here, so it is not claimed as inspected footage.

## Recovered assets used

| Component | Original entry suffix |
| --- | --- |
| Paper | `background/bg.png` |
| Title bar | `background/header-bar.png` |
| Painted navigation | `background/banner.png` |
| Black submenu | `background/submenu-bg.png` |
| Play button | `components/buttonplaynow_en.png` |
| HP / VP / funds | `icons/currency_hp.png`, `currency_vp.png`, `currency_bf.png` |
| Inventory pane | `panels/01_bgframelargelong.png` |
| Olive heading | `panels/01_fgtabwide.png` |
| Item slots | `panels/01_fgslot.png` |
| Equipment bar | `panels/04_bgframe.png`, `04_fgslotframe.png` |
| Animated faction flags | `score/british/scoreboard_flag*.tga`, `score/national/scoreboard_flag*.tga` |
| Health / ammunition | `bars/westiconhealth*.tga`, `bars/westiconammo*.tga` |
| Portrait XP ring | `xpbar/westxpbarframe.tga`, `westxpbarfull.dds` |
| Equipment icons | `weapons/weapon*.tga`, `abilities/ability*.tga` |

`Assets/UI/manifest.json` in a built app maps exact original entry names to exported PNGs. Original archive entries and hashes are recorded by the conversion pipeline.

## Validation

`scripts/check_interface.sh` builds the iOS Simulator app, installs it, launches the menu, store, abilities and gameplay scenes, and captures native screenshots. CI attaches those screenshots alongside the verified unsigned ARM64 IPA. These screenshots demonstrate rendering; they do not substitute for touch playtesting or a performance test on an iPhone.

## Remaining fidelity gaps

The original full ability tree, emotes, widgets, mission catalog, remote store pricing, multiplayer services and vehicle gameplay are not implemented. Only the three existing class skills are available, with local upgrades. Inventory ownership and saved equipment are functional; offline fallback prices are labelled as local prices. No recovered standalone font was available in the menu archive, so text currently uses a native fallback. Native layout and effects still differ from the original Flash and Refractor presentation.
