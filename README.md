# Tiny Threat Plus

A World of Warcraft Forever and Classic (Anniversary, Seasons, Hardcore, Era) addon that enhances Blizzard's native Classic nameplates with clear, actionable threat information while preserving the default UI style.

Tiny Threat Plus is designed to work seamlessly with all 7 built-in Blizzard nameplate styles and sizes, adding threat information you want without replacing your nameplates.

#### **WoW Forever Public Beta**

Tiny Threat Plus supports WoW Forever with a lightweight, Blizzard-native presentation. **Exact signed threat differences are shown only when Blizzard exposes readable threat values**, typically on your current target. Other nameplates may have restricted threat data; the addon will not invent a signed threat lead.

**Known Forever limitations:** Group Target Counter is currently unavailable due to protected unit identity, off-target signed threat differences may be blank, and Target Priority remains experimental. Please report reproducible bugs with the client build, encounter, addon version, and any Lua error.

#### **Features**

* **Threat Display** - See threat differences on readable targets, with restricted off-target information handled according to each client's API.
* **Role-Based Threat Colors** - Health bars dynamically change green, yellow, or red based on whether you're tanking or dealing damage.
* **Threat Leader** - See who currently leads threat, including class-colored names, class/pet icons, and group role.
* **Target Priority** - Highlights a candidate for attention during multi-target combat using available threat information; experimental on Forever.
* **Target Counter** - Counts group members targeting enemies on supported Classic clients; unavailable on Forever while unit identity remains protected.
* **Mob Information** - Adds mob level, difficulty coloring, rare/elite indicators, and raid markers.
* **Pet Support** - Tracks pet threat and includes optional solo Target Priority support for pet classes.
* **Native Blizzard Styling** - Automatically adapts and scales with Classic, Modern, Thin Bars, Blocky Bars, Clean Health, Blocky Cast, and Legacy Red nameplates.

#### **Customization**

* Configure threat displays, colors, thresholds, fonts, sizing, Threat Leader, Target Priority, Target Counter, mob information, class-colored nameplates, and more from Options → AddOns → Tiny Threat Plus.

#### **Forever Compatibility Architecture**

WoW Forever can expose combat and nameplate information as protected/secret values. Tiny Threat Plus follows a native-first compatibility model so those restrictions remain isolated from the addon's shared threat and presentation logic.

* **Blizzard nameplates are authoritative** - nameplate add/remove events define the lifetime of each visible enemy. Tiny Threat Plus enhances Blizzard's plate rather than replacing it or reconstructing enemy identity from protected GUIDs.
* **Events trigger updates; they do not guarantee readable data** - threat, target, aura, and nameplate events are used as update signals even when the associated combat values cannot safely be inspected by Lua.
* **Readable values use the normal threat model** - ordinary values are sanitized and may be cached for Threat Readout and Threat Leader presentation.
* **Protected values remain protected** - when Blizzard provides a supported secret-safe comparison or presentation path, Tiny Threat Plus passes protected state through that path instead of attempting to inspect, compare, measure, or reverse-engineer it in Lua.
* **Restricted Blizzard regions are treated as write-only presentation surfaces** - the addon may safely anchor or style a supported native region, but does not measure restricted frame geometry with APIs such as GetPoint, GetSize, GetWidth, or GetHeight.
* **Anniversary defines behavior; Forever adapts acquisition** - the mature Anniversary implementation remains the functional/display contract. Forever-specific compatibility belongs behind capability checks and should not change shared feature semantics unless Blizzard's protected-data model makes the original behavior unavailable.

The preferred data flow is: **Blizzard lifecycle/event → capability check → readable or protected path → presentation**. Avoid building parallel combat-state or unit-identity systems merely to recover information Blizzard intentionally protects.

#### **Acknowledgements**

*   Concept taken from [Blizz Threat Plates](https://www.curseforge.com/wow/addons/blizz-threat-plates) by [jfrouleau](https://www.curseforge.com/members/jfrouleau/projects)

#### **Known Issues / To-Do**

*   Test with various other popular UI frameworks and addons\n*   Restore reliable off-target threat difference and group target counting on Forever if Blizzard exposes suitable APIs

Updated, uploaded, and maintained (at least for now) by [StormtrooperTK421](https://www.curseforge.com/linkout?remoteUrl=https://discordapp.com/users/237746068844969994) on [GitHub](https://github.com/DustinChecketts/TinyThreatPlus). Please submit issues and I'll do my best to troubleshoot, replicate, and resolve issues as my limited abilities allow.
