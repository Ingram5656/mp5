extends RefCounted
## Model — app settings (v0.5.4). Currently only the interface language, kept in user://mp5_settings.cfg.

const PATH := "user://mp5_settings.cfg"
const LANGS := ["en", "zh"]

var lang := "en"


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		var v: String = cfg.get_value("ui", "lang", "en")
		if v in LANGS:
			lang = v


func set_lang(new_lang: String) -> bool:
	if new_lang == lang or not new_lang in LANGS:
		return false
	lang = new_lang
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "lang", lang)
	cfg.save(PATH)
	return true
