extends RefCounted
## Presenter — Achievements page (v0.5.4). Reads the achievements database and definitions, applies the
## filter and hands the view plain rows grouped by level (v0.7.1) and difficulty.

const AchDefs := preload("res://app_v0.7.1/scripts/models/achievement_defs.gd")

var db
var view
var filter := 0   # 0 all, 1 unlocked, 2 locked


func _init(database, achievements_view) -> void:
	db = database
	view = achievements_view
	view.filter_changed.connect(set_filter)


func set_filter(i: int) -> void:
	filter = i
	render()


func render() -> void:
	var sections: Array = []
	# v0.7.1: Level A (carrot) sections first, then Level B (balloons)
	for game in [AchDefs.GAME_ROCKING, AchDefs.GAME_BALLOON]:
		for g in AchDefs.GROUPS:
			_add_section(sections, game, g)
	view.show_list(db.unlocked_count(), db.total_count(), sections)


func _add_section(sections: Array, game: String, g: Dictionary) -> void:
	var rows: Array = []
	for d in AchDefs.LIST:
		if d["group"] != g["id"] or d.get("game", AchDefs.GAME_ROCKING) != game:
			continue
		var st: Dictionary = db.state(d["id"])
		var un: bool = st["unlocked"]
		if (filter == 1 and not un) or (filter == 2 and un):
			continue
		rows.append({"def": d, "unlocked": un, "unlocked_at": st["unlocked_at"], "progress": st["progress"]})
	if rows.is_empty():
		return
	sections.append({"group": g, "game": game, "rows": rows})
