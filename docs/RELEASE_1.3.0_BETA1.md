# TinyThreatPlus 1.3.0-beta1 — Release checklist

This branch is a **candidate only**. Do not merge, tag, dispatch the release workflow, or publish to CurseForge without the maintainer's approval.

## Before approval

- [ ] Confirm the addon loads on the live WoW Forever client with no Lua errors.
- [ ] Confirm neutral (yellow), hostile (red), friendly (green), and tap-denied (gray) nameplate colors out of combat.
- [ ] Confirm current-target signed threat lead updates during combat.
- [ ] Confirm non-targeted nameplates never present protected absolute threat as a signed lead.
- [ ] Confirm Target Priority stays hidden with one engaged mob even if other mobs are visible.
- [ ] Confirm Target Priority appears with multiple engaged mobs and its width/height/thickness controls work.
- [ ] Confirm selected-target highlighting, target-frame threat box, and level badge positioning.
- [ ] Test party/dungeon tank and DPS situations, nameplate recycling, and combat transitions.
- [ ] Confirm that group Target Counter is not advertised as working on Forever.
- [ ] Regression-test Classic Era and TBC Anniversary or explicitly limit initial publication to Forever.
- [ ] Inspect packaged ZIP: top-level TinyThreatPlus folder; includes TOC, Compat.lua, TinyThreatPlus.lua, Nameplates.lua, Options.lua; excludes .github and docs.
- [ ] Verify CurseForge API secret CF_API_KEY exists and project ID 1603170 is correct.
- [ ] Verify GitHub Actions packaging completes and review any warnings before sharing.

## Release mechanism

- Source branch: `release/1.3.0-beta1`
- Planned version: `1.3.0-beta1`
- Planned tag: `v1.3.0-beta1`
- Workflow: `.github/workflows/release.yml`
- CurseForge project ID in TOC: `1603170`

The release workflow publishes externally when run or when a matching tag is pushed. **Do not run it during preparation.** Its manual dispatch creates a tag before packaging, so use it only after final approval.

## Post-release work (not a blocker)

- Investigate authoritative off-target signed threat snapshots and attention heuristics.
- Explore safe group Target Counter APIs as Blizzard's Forever interface evolves.
- Collect user feedback and reproducible error reports before promoting the beta to a stable release.
