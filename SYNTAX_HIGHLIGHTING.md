# GDScript Barevné Schéma - Syntax Highlighting

Jak vypadá barevný výstup kódu v VS Code pro GDScript:

---

## Příklad Funkce s Barvami:

```gdscript
func zobraz_prehled_statu(data: Dictionary, all_provinces: Dictionary):
│    │                     │    │          │    │               │
│    Name              Param Name  Type     │    │               │
│                                          │    │               │
└─ Tmavá modrá                        Typ (tyrkysová)        Typ (tyrkysová)

    if data.is_empty():
    ││  ││   │
    ││  ││   └─ Metoda (zlatá/oranžová)
    ││  │└───── '.': operátor (bílá)
    ││  └────── Proměnná - data (světle modrá)
    │└───────── Klíčové slovo (tmavá modrá)
    
    var owner_tag = str(data.get("owner", "")).strip_edges().to_upper()
    ││  ││        │ ││  ││   │    │       │  │ │           │
    ││  ││        │ ││  ││   │    └─ String (zelená)
    ││  ││        │ ││  ││   └─ Funkce volání (oranžová)
    ││  ││        │ ││  │└───── '.': oddělač (bílá)
    ││  ││        │ ││  └────── Proměnná (světle modrá)
    ││  ││        │ │└────────── '(': závorka (bílá)
    ││  ││        │ └─────────── Funkce (oranžová)
    ││  ││        └── '=': operátor (bílá)
    ││  │└───────────── Název proměnné (bílá/šedá)
    ││  └────────────── Klíčové slovo (tmavá modrá)
    │└──────────────── Klíčové slovo (tmavá modrá)
```

---

## Barevné Kategorie v GDScript:

| Kategorie | Barva | Příklady |
|-----------|-------|----------|
| **Klíčová Slova (Keywords)** | Tmavá Modrá | `func`, `var`, `if`, `for`, `return`, `class`, `extends` |
| **Typy (Types)** | Tyrkysová/Modrá | `Dictionary`, `String`, `int`, `float`, `bool`, `Array`, `Vector2`, `Node`, `Label`, `Button` |
| **Funkce (Function Names)** | Oranžová/Zlatá | `str()`, `is_empty()`, `get()`, `.to_upper()`, `.strip_edges()` |
| **Proměnné (Variables)** | Světle Modrá | `data`, `owner_tag`, `GameManager`, `player_tag`, `total_pop` |
| **Stringy (Strings)** | Zelená | `"owner"`, `"SEA"`, `""`, `"ideology"` |
| **Čísla (Numbers)** | Červená/Purpurová | `-1`, `0`, `0.0`, `1` |
| **Komentáře (Comments)** | Tmavě Zelená | `# Save the tag for button actions` |
| **Operátoři** | Bílá | `=`, `==`, `:`, `.`, `->`, `(`, `)`, `[`, `]` |
| **Boolean** | Purpurová | `true`, `false` |
| **Speciální Klíčová Slova** | Purpurová | `null`, `self` |

---

## Detailní Rozbor Kódu:

```gdscript
func zobraz_prehled_statu(data: Dictionary, all_provinces: Dictionary):
```

| Část | Barva | Typ | Popis |
|------|-------|-----|-------|
| `func` | Tmavá modrá | Keyword | Deklarace funkce |
| `zobraz_prehled_statu` | Bílá | Function name | Jméno funkce |
| `(` | Bílá | Operátor | Zahájení parametrů |
| `data` | Světle modrá | Parameter name | Jméno prvního parametru |
| `:` | Bílá | Operátor | Oddělač před typem |
| `Dictionary` | Tyrkysová | Type | Typ parametru |
| `,` | Bílá | Operátor | Oddělač parametrů |
| `all_provinces` | Světle modrá | Parameter name | Jméno druhého parametru |
| `:` | Bílá | Operátor | Oddělač před typem |
| `Dictionary` | Tyrkysová | Type | Typ parametru |
| `)` | Bílá | Operátor | Uzavření parametrů |
| `:` | Bílá | Operátor | Začátek těla funkce |

---

```gdscript
var owner_tag = str(data.get("owner", "")).strip_edges().to_upper()
```

| Část | Barva | Typ | Popis |
|------|-------|-----|-------|
| `var` | Tmavá modrá | Keyword | Deklarace proměnné |
| `owner_tag` | Bílá/Šedá | Variable name | Jméno nové proměnné |
| `=` | Bílá | Operátor | Přiřazení |
| `str` | Oranžová | Function | Funkce pro konverzi na string |
| `(` | Bílá | Operátor | Otevření funkce |
| `data` | Světle modrá | Variable | Existující proměnná |
| `.` | Bílá | Operátor | Přístup k metodě |
| `get` | Oranžová | Method | Metoda objektu |
| `(` | Bílá | Operátor | Otevření metody |
| `"owner"` | Zelená | String | Textová hodnota |
| `,` | Bílá | Operátor | Oddělač |
| `""` | Zelená | String | Prázdný string (fallback) |
| `)` | Bílá | Operátor | Uzavření metody |
| `.` | Bílá | Operátor | Řetězení metod |
| `strip_edges` | Oranžová | Method | Metoda pro odstranění mezer |
| `(` `)` | Bílá | Operátor | Volání bez parametrů |
| `.` | Bílá | Operátor | Řetězení metod |
| `to_upper` | Oranžová | Method | Metoda pro velká písmena |
| `(` `)` | Bílá | Operátor | Volání bez parametrů |

---

```gdscript
if data.is_empty():
```

| Část | Barva | Typ | Popis |
|------|-------|-----|-------|
| `if` | Tmavá modrá | Keyword | Podmíněný příkaz |
| `data` | Světle modrá | Variable | Proměnná |
| `.` | Bílá | Operátor | Přístup k metodě |
| `is_empty` | Oranžová | Method | Metoda pro ověření prázdnoty |
| `(` `)` | Bílá | Operátor | Volání metody |
| `:` | Bílá | Operátor | Začátek bloku |

---

## Souhrn Barev (VS Code Default Dark Theme):

| Barva | Kód RGB | Použití |
|-------|---------|--------|
| **Tmavá Modrá** | `#569CD6` | `func`, `var`, `if`, `for`, `return` - klíčová slova |
| **Tyrkysová** | `#4EC9B0` | `Dictionary`, `String`, `int`, `bool` - typy dat |
| **Oranžová/Zlatá** | `#DCDCAA` | `str()`, `get()`, `.to_upper()` - funkce a metody |
| **Světle Modrá** | `#9CDCFE` | `data`, `owner_tag`, proměnné |
| **Zelená** | `#CE9178` | `"text"`, `"owner"` - stringové literály |
| **Purpurová/Červená** | `#C586C0` | `true`, `false`, `null` - boolean a speciální |
| **Tmavě Zelená** | `#6A9955` | `# komentáře` - vypovědi |
| **Bílá/Šedá** | `#D4D4D4` | `.`, `=`, `()`, `[]` - operátoři a závorky |
| **Rezavá Červená** | `#D7BA7D` | `-1`, `0`, `123` - čísela |

---

## Dictionary vs Array - Důležitý Rozdíl:

### **Dictionary** (Slovník)
```gdscript
var stats: Dictionary = {
    "population": 10000,
    "gdp": 50000,
    "ideology": "democracy"
}

# Přístup podle KLÍČE (pojmenované údaje)
print(stats["population"])      # Vrátí: 10000
print(stats.get("gdp"))         # Vrátí: 50000
print(stats["ideology"])        # Vrátí: "democracy"
```

**Vlastnosti:**
- Páry **klíč → hodnota** (klíč musí být unikátní)
- Přístup pomocí jména: `dict["jmeno"]` nebo `dict.get("jmeno")`
- Neuspořádaný (pořadí není zaručeno)
- Ideální pro: pojmenované údaje, stavy, konfigurace

| Použití | Příklad |
|---------|---------|
| Informace o státu | `{"name": "Česko", "gdp": 5000, "population": 10000}` |
| Nastavení | `{"volume": 80, "brightness": 100}` |
| Mapování | `{"CZE": "Česko", "POL": "Polsko"}` |

---

### **Array** (Pole)
```gdscript
var provinces: Array = [1, 2, 3, 4, 5]
var names: Array = ["Praha", "Brno", "Ostrava"]

# Přístup podle INDEXU (pozice v seznamu)
print(provinces[0])      # Vrátí: 1 (první prvek)
print(provinces[2])      # Vrátí: 3 (třetí prvek)
print(names[1])          # Vrátí: "Brno" (druhý prvek)
```

**Vlastnosti:**
- Číslený **index** (začíná od 0)
- Přístup podle pozice: `array[0]`, `array[1]`...
- **Uspořádaný** (pořadí je zaručeno)
- Ideální pro: seznamy, kolekce, sekvence

| Použití | Příklad |
|---------|---------|
| ID provincií | `[1, 2, 3, 4, 5]` |
| Seznam minut | `[0, 5, 10, 15, 20]` |
| Názvy měst | `["Praha", "Brno", "Ostrava"]` |

---

### **Porovnání**

| Aspekt | Dictionary | Array |
|--------|-----------|-------|
| **Typ klíče/indexu** | String (název) | Číslo (pozice) |
| **Přístup** | `dict["key"]` | `array[0]` |
| **Příklad kódu** | `player_stats["health"]` | `provinces[0]` |
| **Vhodné pro** | Pojmenované údaje | Seznamy, sekvence |
| **Rychlost** | Velmi rychlá (hash lookup) | Velmi rychlá (index) |
| **Pořadí** | Není zaručeno | Zaručené |
| **Iterace** | `for key in dict:` | `for item in array:` |

---

### **TYPY V GDSCRIPTU - Všechny Tyrkysové!**

```gdscript
# Primitivní typy
var text: String          # Tyrkysová
var cislo: int            # Tyrkysová
var desitina: float       # Tyrkysová
var pravda: bool          # Tyrkysová

# Kolekční typy
var seznam: Array         # Tyrkysová
var slovnik: Dictionary   # Tyrkysová

# Godot geometrie
var pozice: Vector2       # Tyrkysová
var barva: Color          # Tyrkysová

# Godot objekty (Nodes, komponenty)
var label: Label          # Tyrkysová
var tlacitko: Button      # Tyrkysová
var uzly: Node            # Tyrkysová
var cas: Timer            # Tyrkysová
var camera: Camera2D      # Tyrkysová
var kontrola: Control     # Tyrkysová
```

**Pamatuj:** Všechny TYPY v GDScriptu jsou **TYRKYSOVÉ**, ať už jde o:
- Základní typy: `String`, `int`, `float`, `bool`
- Kolekce: `Array`, `Dictionary`
- Vektory: `Vector2`, `Vector3`, `Transform2D`
- Barvy: `Color`
- Godot objekty: `Node`, `Label`, `Button`, `Control`, `Timer`, `Area2D`, `RigidBody2D` atd.

---

## Zapamatovat:

- **Klíčová slova (Keywords):** `func`, `var`, `if`, `for`, `while`, `return` = Tmavá modrá
- **Typy:** `Dictionary`, `String`, `Array`, `int`, `float` = Tyrkysová
- **Funkce/Metody:** `.get()`, `.is_empty()`, `str()` = Oranžová
- **Proměnné:** `data`, `owner_tag`, `GameManager` = Světle modrá
- **Stringy:** `"text"`, `"owner"` = Zelená
- **Čísla:** `0`, `-1`, `3.14` = Rezavá červená
- **Komentáře:** `#` = Tmavě zelená
- **Operátoři:** `:`, `.`, `=`, `()` = Bílá

To je přesně jak se to zobrazuje v tvém VS Code!
