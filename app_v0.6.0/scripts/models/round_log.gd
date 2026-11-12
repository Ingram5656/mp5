extends RefCounted
## Model (persistence) — per-round CSV log in user://carrot_logs/ (v0.5.4; same format as v0.5.2/v0.5.3,
## except t_s now counts from when the round was opened instead of from when the app started).
## Windows: %APPDATA%\Godot\app_userdata\MP5\carrot_logs\

const DIR := "user://carrot_logs"
const COLUMNS := "t_s,moment_nm,offaxis_nm,pull_n,phase,hold_s,halves,rocks,mistakes,event"

var path := ""
var _f: FileAccess


## prefix: file name start ("rocking_A" for the carrot game, "rocking_B" for the balloon game, v0.6.0).
## columns: the column header line (the carrot game's by default).
func open(header: String, prefix := "rocking_A", columns := COLUMNS) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	path = DIR + "/%s_%s.csv" % [prefix, stamp]
	_f = FileAccess.open(path, FileAccess.WRITE)
	if _f == null:
		return
	_f.store_line(header)
	_f.store_line(columns)


func write(row: String) -> void:
	if _f != null:
		_f.store_line(row)


func is_open() -> bool:
	return _f != null


func close() -> void:
	if _f != null:
		_f.close()
		_f = null
