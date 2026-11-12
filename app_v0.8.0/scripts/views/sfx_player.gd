extends Node
## View — interface sounds (v0.8.0). Two sounds for now, no game sounds yet:
##   click  — every button in the app, the games and the report (toggles too), found automatically
##   swoosh — changing screens (pages, opening a game, coming back, opening / closing a report)
## Sounds live in assets/sfx/ — replace a file with one of the same name to change the sound.
## Any node can ask for the swoosh with get_tree().call_group("mp5_sfx", "play_swoosh").

const CLICK_PATH := "res://assets/sfx/ui_click.wav"
const SWOOSH_PATH := "res://assets/sfx/ui_swoosh.wav"
const CLICK_DB := -6.0
const SWOOSH_DB := -9.0
const GROUP := "mp5_sfx"

var _click: AudioStreamPlayer
var _swoosh: AudioStreamPlayer
var _last_swoosh_ms := -1000


func _ready() -> void:
	add_to_group(GROUP)
	_click = _player(CLICK_PATH, CLICK_DB, 4)
	_swoosh = _player(SWOOSH_PATH, SWOOSH_DB, 1)
	# every button that is (or will be) in the tree clicks
	get_tree().node_added.connect(_on_node_added)
	_hook_tree(get_tree().root)


func _player(path: String, db: float, voices: int) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		p.stream = load(path)
	p.volume_db = db
	p.max_polyphony = voices
	add_child(p)
	return p


func _hook_tree(n: Node) -> void:
	_on_node_added(n)
	for c in n.get_children():
		_hook_tree(c)


func _on_node_added(n: Node) -> void:
	var b := n as BaseButton
	if b != null and not b.pressed.is_connected(play_click):
		b.pressed.connect(play_click)


func play_click() -> void:
	if _click.stream == null:
		return
	_click.pitch_scale = randf_range(0.95, 1.06)
	_click.play()


## Screen change. Two requests closer than 0.2 s play once (a page change inside a cover transition).
func play_swoosh() -> void:
	var now := Time.get_ticks_msec()
	if _swoosh.stream == null or now - _last_swoosh_ms < 200:
		return
	_last_swoosh_ms = now
	_swoosh.play()
