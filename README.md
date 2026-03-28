# RP-2025-26 (Godot Project)

Hi. This is my school-ish project and honestly I am still figuring stuff out while making it.

## What is this

This is a strategy map game project made in Godot.
It uses country/province data, flags, population files and other csv/txt/json files inside `map_data/`.

Main folders:
- `scripts/` - game logic (a lot of important stuff here)
- `scenes/` - Godot scenes
- `map_data/` - all map and country data (also mine...)
- `shaders/` - shader files

## How to run

1. Open Godot (same or newer version than project uses).
2. Import this folder as project.
3. Open `project.godot`.
4. Press Play.

If it crashes, sorry, try reopening project or reimporting assets.

## Build / Export

There is `export_presets.cfg` and also exe files in root, so export was done before.
If export does not work for you:
- check export templates in Godot
- check preset paths
- try clean export again

## Current state

- Works in progress
- Some parts are probably messy
- Data files are big and easy to break if edited wrong

## Notes for anyone touching this

- Please do small changes and test often.
- Keep backup of `map_data/` before editing.
- If something random stops working, it might be because one csv value is bad (happened before).

## Known problems (maybe)

- UI and interactions are not always polished.
- Some logic is hardcoded in scripts.
- Naming is not always perfect.
- a;sp its made in czech language so you know, not exatcly easy for english speaking majority to understand it.
## License

This project is under a non-commercial license.
Nobody can use this project to make profit without my written permission.
See `LICENSE` for full terms.

# why?

- if you shall profit from it, you should left a little sum sum for me too!