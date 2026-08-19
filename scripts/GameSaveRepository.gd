extends "res://scripts/GameArmyLabRules.gd"

## Save-slot repository layer. Runtime snapshot construction remains in the facade orchestration layer.

const SaveRepositoryScript = preload("res://scripts/SaveRepository.gd")
const SAVEGAME_STATE_PATH := "user://savegame.dat"
const SAVE_SLOTS_DIR := "user://saves"
const SAVE_SLOT_EXT := ".dat"

var _save_repository = SaveRepositoryScript.new(
	SAVEGAME_STATE_PATH,
	SAVE_SLOTS_DIR,
	SAVE_SLOT_EXT
)

func _normalizuj_nazev_save(slot_name: String) -> String:
	return _save_repository.normalize_slot_name(slot_name)

func _cesta_slotu_save(slot_name: String) -> String:
	return _save_repository.slot_path(slot_name)

func _zajisti_slozku_save() -> void:
	_save_repository.ensure_slots_directory()

func _uloz_state_do_cesty(path: String, state: Dictionary) -> bool:
	return _save_repository.write_state(path, state)

func _nacti_state_z_cesty(path: String) -> Dictionary:
	return _save_repository.read_state(path)

func ziskej_save_sloty() -> Array:
	return _save_repository.list_slots()

func ziskej_save_slot_pro_kolo(turn_number: int) -> String:
	if turn_number <= 0:
		return ""
	for slot_any in ziskej_save_sloty():
		var slot = slot_any as Dictionary
		var slot_path = str(slot.get("path", ""))
		if slot_path == "":
			continue
		var state = _nacti_state_z_cesty(slot_path)
		if state.is_empty():
			continue
		if int(state.get("aktualni_kolo", -1)) == turn_number:
			return str(slot.get("name", ""))
	return ""

func ma_save_pro_kolo(turn_number: int) -> bool:
	return ziskej_save_slot_pro_kolo(turn_number) != ""

func ma_ulozene_hry() -> bool:
	return _save_repository.has_any_save()

func smaz_save_slot(slot_name: String) -> bool:
	return _save_repository.delete_slot(slot_name)

func smaz_legacy_save() -> bool:
	return _save_repository.delete_legacy_save()
