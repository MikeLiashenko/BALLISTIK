extends Node
## Музыка (Autoload): треки из res://sounds, плейлисты меню и боя, плавные переходы между ними
## (два проигрывателя с перекрёстным затуханием), приглушение на паузе. Воспроизведение идёт
## через шину Music — громкость настраивается отдельно от эффектов.

signal track_changed(title: String)

const TRACKS := {
	"briefing": {"title": "Briefing at Midnight", "path": "res://sounds/Briefing_At_Midnight.mp3"},
	"intercept": {"title": "Intercept Vector", "path": "res://sounds/Intercept_Vector.mp3"},
	"target": {"title": "Target Locked in Salt", "path": "res://sounds/Target_Locked_In_Salt.mp3"},
}
const MENU_PLAYLIST: Array[String] = ["briefing", "intercept", "target"]
const BATTLE_PLAYLIST: Array[String] = ["intercept", "target"]
const FADE_TIME := 1.8
const DUCK_DB := -9.0

var current_title: String = ""
var mode: String = ""

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _playlist: Array[String] = []
var _index: int = 0
var _streams: Dictionary = {}
var _ducked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = GameSettings.BUS_MUSIC
		p.volume_db = -80.0
		p.finished.connect(_on_finished.bind(i))
		add_child(p)
		_players.append(p)


func play_menu() -> void:
	_start_mode("menu", MENU_PLAYLIST, false)


func play_battle() -> void:
	_start_mode("battle", BATTLE_PLAYLIST, true)


## Приглушить музыку (пауза, экран итогов) или вернуть громкость.
func duck(enabled: bool) -> void:
	if _ducked == enabled:
		return
	_ducked = enabled
	var p := _players[_active]
	if p.playing:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", _target_db(), 0.6)


func _target_db() -> float:
	return DUCK_DB if _ducked else 0.0


func _start_mode(new_mode: String, list: Array[String], shuffle: bool) -> void:
	if mode == new_mode and _players[_active].playing:
		return
	mode = new_mode
	_playlist = list.duplicate()
	if shuffle:
		_playlist.shuffle()
	_index = 0
	_crossfade_to(_playlist[0])


func _stream(key: String) -> AudioStream:
	if _streams.has(key):
		return _streams[key]
	var info: Dictionary = TRACKS.get(key, {})
	var stream: AudioStream = null
	if not info.is_empty() and ResourceLoader.exists(str(info["path"])):
		stream = load(str(info["path"])) as AudioStream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	_streams[key] = stream
	return stream


func _crossfade_to(key: String) -> void:
	var stream := _stream(key)
	if stream == null:
		return
	var old := _players[_active]
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	p.volume_db = -40.0
	p.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "volume_db", _target_db(), FADE_TIME).set_trans(Tween.TRANS_SINE)
	if old.playing:
		tw.tween_property(old, "volume_db", -80.0, FADE_TIME)
		tw.chain().tween_callback(old.stop)
	current_title = str((TRACKS[key] as Dictionary)["title"])
	track_changed.emit(current_title)


func _on_finished(index: int) -> void:
	if index != _active or _playlist.is_empty():
		return
	_index = (_index + 1) % _playlist.size()
	_crossfade_to(_playlist[_index])
