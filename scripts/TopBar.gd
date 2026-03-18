extends CanvasLayer

@onready var money_label = $Panel/HBoxContainer/MoneyLabel
@onready var turn_label = $Panel/HBoxContainer/TurnLabel
@onready var next_btn = $Panel/HBoxContainer/NextTurnButton

func _ready():
	# Propojíme kliknutí na tlačítko s naší funkcí
	next_btn.pressed.connect(_on_next_turn_pressed)
	
	# Napíchneme se na signál z GameManagera. 
	# Kdykoliv se změní kolo, automaticky se zavolá funkce aktualizuj_ui
	GameManager.kolo_zmeneno.connect(aktualizuj_ui)
	
	# Prvotní nastavení textů hned po zapnutí hry
	aktualizuj_ui()

# Funkce, která jen vezme data z GameManagera a přepíše texty
func aktualizuj_ui():
	# Zobrazíme peníze a do závorky přidáme zelené plus a příjem
	money_label.text = "Kasa: %.2f mil. USD (+%.2f)" % [GameManager.statni_kasa, GameManager.celkovy_prijem]
	turn_label.text = "Kolo: %d" % GameManager.aktualni_kolo

# Co se stane, když klikneš na tlačítko "Další tah"
func _on_next_turn_pressed():
	# Zavoláme logiku v GameManageru, která přičte peníze a posune kolo
	GameManager.ukonci_kolo()
