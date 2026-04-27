# Pouziti AI pri kodovani

Datum: 2026-04-27
Projekt: RP-2025-26

- Celou strukturu a architekturu projektu jsem navrhl a postavil sam — rozdeleni do souboru, jak spolu scripty komunikuji, herni smycka, save/load system, UI layout.
- AI (ChatGPT, GitHub Copilot) mi pomohla vygenerovat nektere konkretni funkce, hlavne v `GameManager.gd`, `GameUI.gd` a `map_loader.gd` — boilerplate, opakujici se vzory, pomocne vypocty.
- Vse co AI navrhla jsem dal rozvinul, upravil a zabudoval do projektu — vzdy jsem to precetl a otestoval, nikdy neskopiroval cely blok naslepo.
- AI jsem vyuzival hlavne jako prirucni encyklopedii: kdyz jsem nevedel jak neco v GDScript napsat, jak funguje nejaky algoritmus, nebo kdyz jsem potreboval rychle overit prisip neceho.
- Herni design, mechaniky, balanc a konkretni naucky jako robin cycle, potato mode, cinematic flyby, vasalstvi nebo kapital presun jsem vymyslel a implementoval sam.

---

## Nejslozitejsi AI-asistovane funkce

Poznamka: uvadim jen slozitejsi a herne relevantni casti. Boilerplate a jednoduche utility zamerne neuvadi.

### scripts/GameManager.gd

- `:1570` `nacti_hru` — nacteni a obnova komplexniho stavu hry
- `:4133` `_trade_can_declare_war` — validace podminek pro vyhlaseni valky pres trade
- `:4296` `_trade_update_map_after_changes` — propagace zmen obchodu do mapy a navaznych systemu
- `:4355` `_vyhodnot_trade_nabidku_ai` — vyhodnoceni obchodni nabidky AI proti vice kriteriim
- `:7043` `_anektuj_cely_stat` — hromadna anexe statu po valce
- `:12844` `_ai_otevri_valky` — rozhodovaci logika AI pro zahajeni valek
- `:12949` `_navrhni_krizovy_protiutok` — navrh krizoveho protiutoku AI
- `:13466` `_navrhni_namorni_presun` — navrh namorniho presunu AI

### scripts/GameUI.gd

- `:6867` `obsluha_vyberu_trade_valky_z_mapy` — vazba mapoveho vyberu na valecny trade flow
- `:7059` `obsluha_vyberu_trade_provincie_z_mapy` — mapovy vyber provincii pro obchod
- `:8778` `_vytvor_otisk_diplomaticke_fronty` — snapshot stavu diplomaticke fronty

### scripts/map_loader.gd

- `:1222` `_aktualizuj_anim_markery` — synchronizace animovanych markeru s aktualnim stavem mapy
- `:1288` `_pridej_animovany_marker` — vytvareni a sprava markeru v mapove vrstve
- `:1452` `generuj_nazvy_provincii` — generovani nazvu provincii nad datovym podkladem mapy

### scripts/map_interaction.gd

- `:939` `_zpracuj_interakci` — hlavni routing kliknuti/interakci na mape podle aktivniho modu

### plna verze (priloha_a.txt)