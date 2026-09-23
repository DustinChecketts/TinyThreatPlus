# Changelog

## 1.3.0

### WoW Forever
- Added WoW Forever 1.60.x support.
- Added a Forever compatibility layer for restricted and secret-value APIs.
- Added custom Forever nameplate presentation while retaining Blizzard-owned health, cast, visibility, and unit handling.
- Added threat delta display to Forever nameplates and the target frame.
- Added pet-aware threat handling and Threat Leader presentation.
- Added Target Counter support for hostile targets while excluding friendly targets.
- Added Target Priority support with Forever-safe health handling.
- Added custom mob level presentation and suppressed incompatible native Forever level/selection artwork.
- Added Forever-aware cast-bar and nameplate geometry.
- Added support for Blizzard's Forever nameplate size/style families.

### Architecture
- Added `Compat.lua` as the client/API compatibility boundary.
- Split nameplate presentation into `Nameplates.lua`.
- Preserved Blizzard ownership of protected nameplate mechanics while TinyThreatPlus owns presentation.
- Documented the reusable Forever UI ownership pattern in `docs/FOREVER_UI_ARCHITECTURE.md`.
- Kept the threat diagnostic source in the repository but excluded it from production packages.

### Compatibility
- WoW Forever: tested on the 1.60.1 beta client.
- TBC Anniversary and Classic Era support remain in the shared addon.
