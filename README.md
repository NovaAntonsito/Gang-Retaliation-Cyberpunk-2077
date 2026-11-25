# Gang Retaliation - map filter, stronghold and intel work

Source tree for our changes to NovaAntonsito's Gang Retaliation (Cyberpunk 2077), laid out like the game folder
(`archive/`, `r6/`, `bin/` at the top). Same layout as the other mods in `Working/`.

- `r6/scripts/GangRetaliation/` Redscript (`Stronghold.reds`: strongholds, intel, map filter, tooltips)
- `r6/tweaks/GangRetaliation/intel.yaml` TweakXL (marker variant, filter group, extract action)
- `archive/pc/mod/` compiled archives (`GangRetaliationBanners.archive` = stronghold banners)
- `bin/x64/plugins/cyber_engine_tweaks/mods/GangRetaliation/` CET Lua
- `build/gang-logo-atlas/` scripts and sheets used to build the banner atlas (WolvenKit project: `../../WolvenkitProjects/gangretaliation`)
- `docs/` diffs and the change summary
- `NOTES.md` working notes (context, design, verified facts, open items; `NOTES.es.md` = Spanish copy, keep both in sync); `CLAUDE.md` pointer for AI assistants
- `CHANGELOG.md` release notes; built releases go in `../../Distribution/GangRetaliation/<version>/`

Current version: 1.5.7. Nova's original zips are kept in `Other/GangRetaliation_vendor_zips/`.
