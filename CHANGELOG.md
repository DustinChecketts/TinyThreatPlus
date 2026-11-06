# Changelog

## 1.3.0-beta1 — WoW Forever public beta

### WoW Forever
- Initial public beta for the live WoW Forever client, based on in-game testing.
- Enhances Blizzard's native nameplates with compact threat readouts, target-frame threat, mob-level badges, and configurable styling.
- Shows exact signed threat differences when Blizzard exposes readable values (most reliably on the current target).
- Uses supported protected threat-state coloring where possible on other nameplates; off-target exact threat differences are not guaranteed.
- Adds configurable Target Priority outlines for encounters with multiple engaged enemies.
- Preserves native NPC reaction and tap colors outside meaningful threat.
- Adds compatibility safeguards for protected values and nameplate identity.

### Known limitations
- Blizzard's protected threat APIs can prevent signed threat differences on non-targeted mobs; readouts may be unavailable rather than estimated.
- Group Target Counter is not reliably available on Forever and is intentionally disabled there.
- Target Priority is experimental and should not be treated as a guaranteed threat prediction.
- Some nameplate combinations and group encounters still require broader testing.

### Other clients
- The shared codebase retains Classic Era and TBC Anniversary support, but this release candidate has not yet been regression-tested on those clients.

