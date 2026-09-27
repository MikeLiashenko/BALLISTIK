extends Node
## Настройки игры (Autoload): звук (общая громкость, музыка, эффекты), управление, графика и параметры
## матча (карта, эпоха авиации, сложность). Сохраняются в user://settings.cfg. Здесь же программно
## регистрируются аудиошины Music/SFX и карта ввода (InputMap): клавиши задаются физическими кодами,
## поэтому управление работает при любой раскладке (в т.ч. ЙЦУКЕН).

signal settings_changed

const SAVE_PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Низкое", "Среднее", "Высокое", "Ультра"]
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const TOUCH_MODE_NAMES := ["Авто", "Включено", "Выключено"]

var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.9
var mouse_sensitivity: float = 1.0
var invert_y: bool = false
var aircraft_mouse_aim: bool = true
var touch_mode: int = 0
var quality: int = 2
var fullscreen: bool = false
var show_fps: bool = false
var difficulty: int = 1
var team_size: int = 7
var score_limit: int = 1000
var time_limit_min: int = 15
var player_team: int = 0
var map_id: String = "random"
var air_era: int = 0
var force_touch_cmdline: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_setup_input_map()
	if OS.has_feature("mobile"):
		quality = 0
	load_settings()
	for arg in OS.get_cmdline_user_args():
		if arg == "--touch":
			force_touch_cmdline = true
		elif arg.begins_with("--quality="):
			quality = clampi(int(arg.get_slice("=", 1)), 0, QUALITY_NAMES.size() - 1)
	apply_settings()


func _setup_audio_buses() -> void:
	for bus_name: String in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")


func is_touch_enabled() -> bool:
	if force_touch_cmdline:
		return true
	match touch_mode:
		1:
			return true
		2:
			return false
	return is_mobile()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	master_volume = float(cfg.get_value("audio", "master_volume", master_volume))
	music_volume = float(cfg.get_value("audio", "music_volume", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
	mouse_sensitivity = float(cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(cfg.get_value("controls", "invert_y", invert_y))
	aircraft_mouse_aim = bool(cfg.get_value("controls", "aircraft_mouse_aim", aircraft_mouse_aim))
	touch_mode = int(cfg.get_value("controls", "touch_mode", touch_mode))
	quality = int(cfg.get_value("video", "quality", quality))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	show_fps = bool(cfg.get_value("video", "show_fps", show_fps))
	difficulty = int(cfg.get_value("match", "difficulty", difficulty))
	team_size = int(cfg.get_value("match", "team_size", team_size))
	score_limit = int(cfg.get_value("match", "score_limit", score_limit))
	time_limit_min = int(cfg.get_value("match", "time_limit_min", time_limit_min))
	player_team = int(cfg.get_value("match", "player_team", player_team))
	map_id = str(cfg.get_value("match", "map_id", map_id))
	air_era = int(cfg.get_value("match", "air_era", air_era))
	_clamp_values()


func save_settings() -> void:
	_clamp_values()
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("controls", "aircraft_mouse_aim", aircraft_mouse_aim)
	cfg.set_value("controls", "touch_mode", touch_mode)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("match", "difficulty", difficulty)
	cfg.set_value("match", "team_size", team_size)
	cfg.set_value("match", "score_limit", score_limit)
	cfg.set_value("match", "time_limit_min", time_limit_min)
	cfg.set_value("match", "player_team", player_team)
	cfg.set_value("match", "map_id", map_id)
	cfg.set_value("match", "air_era", air_era)
	cfg.save(SAVE_PATH)


func _clamp_values() -> void:
	master_volume = clampf(master_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	mouse_sensitivity = clampf(mouse_sensitivity, 0.2, 3.0)
	touch_mode = clampi(touch_mode, 0, 2)
	quality = clampi(quality, 0, QUALITY_NAMES.size() - 1)
	difficulty = clampi(difficulty, 0, GameDB.DIFFICULTY_LEVELS.size() - 1)
	air_era = clampi(air_era, 0, GameDB.ERA_NAMES.size() - 1)
	if map_id != MapPresets.RANDOM_ID and not MapPresets.MAPS.has(map_id):
		map_id = MapPresets.RANDOM_ID
	team_size = clampi(team_size, 2, 16)
	score_limit = clampi(score_limit, 200, 5000)
	time_limit_min = clampi(time_limit_min, 3, 60)
	player_team = clampi(player_team, 0, 1)


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.001)
	for pair: Array in [[BUS_MUSIC, music_volume], [BUS_SFX, sfx_volume]]:
		var idx := AudioServer.get_bus_index(str(pair[0]))
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(pair[1]), 0.0001)))
			AudioServer.set_bus_mute(idx, float(pair[1]) <= 0.001)
	if not is_mobile() and DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	settings_changed.emit()


## Применяет качество графики к вьюпорту (сглаживание, масштаб 3D-рендера).
func apply_viewport_quality(viewport: Viewport) -> void:
	viewport.use_debanding = quality >= 2
	match quality:
		0:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if not is_mobile() else Viewport.SCREEN_SPACE_AA_DISABLED
			viewport.scaling_3d_scale = 0.75 if is_mobile() else 1.0
		1:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			viewport.scaling_3d_scale = 0.9 if is_mobile() else 1.0
		2:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			viewport.scaling_3d_scale = 1.0
		_:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
			viewport.scaling_3d_scale = 1.0


func particle_scale() -> float:
	return [0.45, 0.75, 1.0, 1.25][quality]


## Разрешение сетки высот рельефа (узлов по стороне) по качеству графики.
func terrain_resolution() -> int:
	return [512, 768, 1024, 1024][quality]


# --- Карта ввода ------------------------------------------------------------------------------------
func _setup_input_map() -> void:
	_add_keys("move_forward", [KEY_W])
	_add_keys("move_back", [KEY_S])
	_add_keys("move_left", [KEY_A])
	_add_keys("move_right", [KEY_D])
	_add_keys("arrow_up", [KEY_UP])
	_add_keys("arrow_down", [KEY_DOWN])
	_add_keys("arrow_left", [KEY_LEFT])
	_add_keys("arrow_right", [KEY_RIGHT])
	_add_keys("yaw_left", [KEY_Q])
	_add_keys("yaw_right", [KEY_E])
	_add_keys("fire_primary", [KEY_SPACE])
	_add_keys("fire_secondary", [KEY_F])
	_add_keys("special", [KEY_G])
	_add_keys("flares", [KEY_X])
	_add_keys("zoom", [KEY_Z])
	_add_keys("radar_mode", [KEY_T])
	_add_keys("camera_mode", [KEY_C])
	_add_keys("scoreboard", [KEY_TAB])
	_add_keys("pause", [KEY_ESCAPE, KEY_P])
	_add_keys("help", [KEY_F1])
	_add_keys("confirm", [KEY_ENTER, KEY_KP_ENTER])
	_add_mouse("fire_primary", MOUSE_BUTTON_LEFT)
	_add_mouse("fire_secondary", MOUSE_BUTTON_RIGHT)
	_add_mouse("special", MOUSE_BUTTON_MIDDLE)
	# Геймпад
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_joy_axis("fire_primary", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_axis("fire_secondary", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joy_button("special", JOY_BUTTON_A)
	_add_joy_button("flares", JOY_BUTTON_B)
	_add_joy_button("radar_mode", JOY_BUTTON_Y)
	_add_joy_button("zoom", JOY_BUTTON_X)
	_add_joy_button("yaw_left", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("yaw_right", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button("pause", JOY_BUTTON_START)
	_add_joy_button("scoreboard", JOY_BUTTON_BACK)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)


func _add_keys(action: String, keys: Array) -> void:
	_ensure_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: MouseButton) -> void:
	_ensure_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, button: JoyButton) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
