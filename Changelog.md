# Changelog

All notable changes are documented here.

## v0.2.0 - 2026-04-01
Compared to: v0.1.1-pre-alpha (0.1.1 line)

### Added
- New alliances system foundation.
- Added `scripts/AlliancesManager.gd` and integration points.
- Added alliance data files:
  - `map_data/Alliances.csv`
  - `map_data/CountryAllianceMembership.csv`
- Added experimental "potato mode".

### Improved
- Major AI updates (aggressiveness, strategy thinking, and overall logic behavior).
- More advanced AI behavior and multiple follow-up tuning passes.
- Improved vassals window to a more user-friendly structure.
- Map/game flow updates across core scripts:
  - `scripts/GameManager.gd`
  - `scripts/GameUI.gd`
  - `scripts/MainMenu.gd`
  - `scripts/map_loader.gd`
  - `scripts/map_interaction.gd`

### Fixed
- Quick fixes and general bug-fix passes (including AI and army movement related issues).
- Camera movement behavior fixes.

### Technical
- Performance and optimization passes in multiple areas.
- Updated shader behavior in `shaders/province_highlight.gdshader`.
- Scene/project/export config updates for the current build pipeline.

### Diff Summary
- 18 files changed
- 4306 insertions
- 450 deletions
