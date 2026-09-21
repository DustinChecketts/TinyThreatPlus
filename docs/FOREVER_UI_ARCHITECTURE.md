# Forever UI Ownership Pattern

## Purpose

This document records the architecture learned while porting TinyThreatPlus to
WoW Forever. It is intended to be reusable by other Forever addons that need to
change Blizzard UI presentation without replacing Blizzard's protected logic.

## Core rule

**Keep Blizzard as the functional owner; let the addon own presentation.**

For nameplates, Blizzard should continue to own:

- world/nameplate discovery and unit association;
- health and cast state;
- protected/secret-value handling;
- visibility and world positioning;
- aura/cast/nameplate lifecycle.

The addon may safely own presentation layered on that live frame:

- geometry of exposed containers;
- addon-created borders, textures and FontStrings;
- placement of Blizzard-exposed name text;
- custom level/classification/threat indicators;
- consistent visual layout independent of Blizzard style choices.

Do not create an independent replacement world-nameplate system unless there is
a compelling reason. Re-skinning the live Blizzard UnitFrame preserves the
client behavior we cannot or should not reproduce.

## Evidence from Forever

Forever's visible nameplate presentation does not map one-to-one to the obvious
Lua frame fields. In testing, UnitFrame.LevelFrame reported hidden while the
native inline level numeral remained visible. Recursively scanning normal
children/regions also found no FontString containing that numeral.

The Blizzard Nameplates options preview is not a reliable substitute for a live
world plate. Manipulating LevelFrame changed/broke the preview while failing to
remove the live-world numeral.

Therefore:

1. Diagnose and test against live NamePlate# frames.
2. Do not infer visible ownership from field names alone.
3. Prefer replacing the complete presentation layer over fighting one native
   visual region at a time.

## ClassicUIForever reference

ClassicUIForever demonstrates the useful pattern on Forever:

- retain Blizzard's NamePlate and UnitFrame;
- retain HealthBarsContainer/healthBar and CastBarsContainer/castBar;
- resize/re-anchor those exposed containers from the addon's own layout pass;
- fade/suppress Blizzard presentation artwork;
- draw addon-owned border and level text;
- reposition Blizzard's exposed name and aura frames;
- respond to NAME_PLATE_UNIT_ADDED and related events;
- periodically re-apply presentation rather than injecting code into the middle
  of Blizzard's own protected health update.

The important idea is architectural, not the Classic visual dimensions.

## Protected/secret-value rule

Forever can return secret values from otherwise familiar APIs, especially in
combat. Presentation code must never assume UnitHealth, UnitHealthMax, threat,
or similar values are ordinary numbers.

Use Compat helpers and capability checks. If a value is secret/inaccessible,
leave the Blizzard-owned functional state alone and omit addon calculations that
require reading it.

Avoid hooks that execute inside Blizzard's own health/nameplate update pass.
An addon operation in that call chain can cause later Blizzard reads to become
refused/tainted. Prefer an addon-owned event/update pass.

## TinyThreatPlus custom layout

The Forever custom layout intentionally keeps:

    NamePlate
      -> UnitFrame
         -> HealthBarsContainer
            -> healthBar (Blizzard live StatusBar)

TinyThreatPlus then owns the visible shell:

    Blizzard health fill
      + TTP border
      + TTP circular level badge
      + TTP threat box
      + TTP target counter
      + TTP threat-leader presentation

The native name FontString may be repositioned rather than recreated.

This gives TTP one stable geometry instead of separately compensating for
Default, Large, Block, Cast Focus, and target-emphasis variants.

## Preview rule

Never deliberately skin the Blizzard Settings preview as proof that the live
implementation works. A preview token/frame may follow a different rendering
path. Live NamePlate# frames are authoritative for runtime behavior.

## Restoration / coexistence

Any future user-facing Custom Nameplate Layout toggle must have a restoration
path. Addon-owned regions should be hidden and Blizzard-owned alpha/scale/layout
returned to Blizzard when custom presentation is disabled. Until restoration is
complete, treat the Forever custom presentation as one-way for the current UI
session and use /reload when changing modes.

## Source reference

Architecture investigated from the MIT-licensed ClassicUIForever project,
especially its NamePlates.lua implementation. TinyThreatPlus should adapt the
pattern to its own design rather than copy Classic visual styling.
