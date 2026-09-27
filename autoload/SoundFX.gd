extends Node
## Процедурный звук (Autoload). Все эффекты синтезируются при запуске в AudioStreamWAV
## (16 бит, моно): выстрелы, взрывы, пуски ракет, всплески, сигналы захвата, звуки интерфейса
## и зацикленные звуки двигателей (турбина, рядный и звездообразный поршневые моторы, дизель, катер).
## Эффекты идут через шину SFX (громкость — в настройках), музыка — через MusicPlayer.

const MIX_RATE := 22050
const POOL_3D := 32
const POOL_2D := 10

var _streams: Dictionary = {}
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _next_3d: int = 0
var _next_2d: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1337
	_generate_all()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.max_distance = 4500.0
		p.unit_size = 30.0
		p.bus = GameSettings.BUS_SFX
		add_child(p)
		_pool_3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = GameSettings.BUS_SFX
		add_child(p)
		_pool_2d.append(p)


func has_sound(key: String) -> bool:
	return _streams.has(key)


func get_stream(key: String) -> AudioStream:
	return _streams.get(key)


## Проиграть звук в точке мира.
func play_3d(key: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, unit_size: float = 30.0) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	var p := _acquire_3d()
	p.stream = stream
	p.global_position = pos
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.pitch_scale = maxf(pitch * _rng.randf_range(0.94, 1.06), 0.05)
	p.play()


## Проиграть звук интерфейса (без позиционирования).
func play_ui(key: String, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	var p := _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % POOL_2D
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Создаёт зацикленный 3D-источник (двигатель) — вызывающий добавляет его к своему узлу.
func create_loop_player(key: String, volume_db: float = -8.0, unit_size: float = 12.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams.get(key)
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = 1200.0
	p.autoplay = false
	p.bus = GameSettings.BUS_SFX
	return p


func _acquire_3d() -> AudioStreamPlayer3D:
	for i in POOL_3D:
		var idx := (_next_3d + i) % POOL_3D
		if not _pool_3d[idx].playing:
			_next_3d = (idx + 1) % POOL_3D
			return _pool_3d[idx]
	var p := _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % POOL_3D
	return p


# --- Синтез ------------------------------------------------------------------------------------------
func _generate_all() -> void:
	_streams["cannon"] = _to_wav(_gunshot(0.16, 0.024, 0.32, 95.0, 0.55))
	_streams["cannon_air"] = _to_wav(_gunshot(0.11, 0.016, 0.45, 130.0, 0.4))
	_streams["mg"] = _to_wav(_gunshot(0.09, 0.012, 0.55, 150.0, 0.35))
	_streams["flak"] = _to_wav(_explosion(0.45, 0.07, 0.25, 70.0))
	_streams["explosion"] = _to_wav(_explosion(2.2, 0.45, 0.05, 48.0))
	_streams["explosion_big"] = _to_wav(_explosion(3.6, 0.9, 0.028, 38.0))
	_streams["missile"] = _to_wav(_whoosh(1.9, 0.35, 0.07, 0.04, 0.9))
	_streams["launch_heavy"] = _to_wav(_whoosh(3.0, 0.22, 0.04, 0.08, 1.4))
	_streams["splash"] = _to_wav(_splash(1.1, 0.26))
	_streams["splash_small"] = _to_wav(_splash(0.35, 0.07))
	_streams["hit"] = _to_wav(_metal_hit(0.14))
	_streams["torpedo"] = _to_wav(_splash(0.8, 0.2))
	_streams["flare"] = _to_wav(_whoosh(0.35, 0.6, 0.2, 0.01, 0.2))
	_streams["bomb_release"] = _to_wav(_gunshot(0.2, 0.05, 0.15, 60.0, 0.6))
	_streams["ui_click"] = _to_wav(_tone(1250.0, 0.06, 0.5, false, 0.012))
	_streams["ui_hover"] = _to_wav(_tone(2100.0, 0.035, 0.25, false, 0.008))
	_streams["ui_confirm"] = _to_wav(_two_tone(900.0, 1400.0, 0.16, 0.5))
	_streams["beep"] = _to_wav(_tone(1000.0, 0.07, 0.45, true, 0.02))
	_streams["locked"] = _to_wav(_tone(1600.0, 0.22, 0.45, true, 0.2))
	_streams["warning"] = _to_wav(_two_tone(1150.0, 780.0, 0.3, 0.55))
	_streams["engine_jet"] = _to_wav(_engine_jet(), true)
	_streams["engine_diesel"] = _to_wav(_engine_pulse(24.0, 0.09, 55.0), true)
	_streams["engine_boat"] = _to_wav(_engine_pulse(36.0, 0.14, 72.0), true)
	_streams["engine_prop"] = _to_wav(_engine_piston(62.0, 93.0, 1.0), true)
	_streams["engine_radial"] = _to_wav(_engine_piston(41.0, 70.0, 1.8), true)


func _to_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var n := samples.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav


func _normalize(buf: PackedFloat32Array, peak: float = 0.92) -> PackedFloat32Array:
	var m := 0.0001
	for s in buf:
		m = maxf(m, absf(s))
	var k := peak / m
	for i in buf.size():
		buf[i] *= k
	return buf


## Короткий выстрел: шумовой импульс + низкочастотный «удар» с падением тона.
func _gunshot(duration: float, decay: float, lp: float, thump_hz: float, thump_amp: float) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var white := _rng.randf_range(-1.0, 1.0)
		y += lp * (white - y)
		phase += TAU * thump_hz * maxf(1.0 - t * 3.0, 0.3) / MIX_RATE
		var env := exp(-t / decay)
		var fade := minf((duration - t) / 0.01, 1.0)
		out[i] = (y * env * 1.8 + sin(phase) * exp(-t / (decay * 2.5)) * thump_amp) * fade
	return _normalize(out, 0.9)


## Взрыв: резкий «хлопок» + низкочастотный рокот + суббас.
func _explosion(duration: float, decay: float, rumble_lp: float, sub_hz: float) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y1 := 0.0
	var y2 := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var white := _rng.randf_range(-1.0, 1.0)
		y1 += rumble_lp * (white - y1)
		y2 += rumble_lp * 0.5 * (y1 - y2)
		var crack := white * exp(-t / 0.02) * 0.7
		var body := (y1 * 2.0 + y2 * 3.0) * exp(-t / decay)
		phase += TAU * sub_hz * (1.0 - 0.4 * t / duration) / MIX_RATE
		var sub := sin(phase) * exp(-t / (decay * 0.6)) * 0.5
		var attack := minf(t / 0.004, 1.0)
		var fade := minf((duration - t) / 0.05, 1.0)
		out[i] = (crack + body + sub) * attack * fade
	return _normalize(out, 0.95)


## Шипение реактивной струи (пуск ракеты) с «открывающимся» фильтром.
func _whoosh(duration: float, lp_start: float, lp_end: float, attack: float, release: float) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var k := t / duration
		var lp := lerpf(lp_start, lp_end, k)
		var white := _rng.randf_range(-1.0, 1.0)
		if _rng.randf() < 0.003:
			white *= 4.0
		y += lp * (white - y)
		var env := minf(t / attack, 1.0) * clampf((duration - t) / release, 0.0, 1.0)
		out[i] = y * env
	return _normalize(out, 0.85)


## Всплеск: высокочастотный шум с «булькающей» модуляцией.
func _splash(duration: float, decay: float) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var white := _rng.randf_range(-1.0, 1.0)
		low += 0.08 * (white - low)
		var high := white - low
		var bubble := 0.65 + 0.35 * sin(TAU * 17.0 * t + sin(TAU * 5.0 * t) * 2.0)
		var env := exp(-t / decay) * minf(t / 0.006, 1.0)
		var fade := minf((duration - t) / 0.03, 1.0)
		out[i] = (high * 0.7 + low * 1.4) * env * bubble * fade
	return _normalize(out, 0.8)


## Металлический звук попадания.
func _metal_hit(duration: float) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var s := sin(TAU * 1830.0 * t) * exp(-t / 0.03) * 0.5
		s += sin(TAU * 2740.0 * t) * exp(-t / 0.02) * 0.35
		s += sin(TAU * 4150.0 * t) * exp(-t / 0.012) * 0.2
		s += _rng.randf_range(-1.0, 1.0) * exp(-t / 0.004) * 0.6
		out[i] = s * minf((duration - t) / 0.01, 1.0)
	return _normalize(out, 0.8)


func _tone(freq: float, duration: float, volume: float, square: bool, decay: float) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var s := sin(TAU * freq * t)
		if square:
			s = clampf(s * 3.0, -1.0, 1.0) * 0.6
		var env := minf(t / 0.004, 1.0) * minf((duration - t) / 0.006, 1.0)
		if decay > 0.0:
			env *= lerpf(1.0, exp(-t / decay), 0.6)
		out[i] = s * env * volume
	return out


func _two_tone(f1: float, f2: float, duration: float, volume: float) -> PackedFloat32Array:
	var n := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var f := f1 if t < duration * 0.5 else f2
		phase += TAU * f / MIX_RATE
		var env := minf(t / 0.005, 1.0) * minf((duration - t) / 0.01, 1.0)
		out[i] = clampf(sin(phase) * 2.5, -1.0, 1.0) * 0.5 * env * volume
	return out


## Зацикленный гул турбины: шумовой поток + гармоники + свист (частоты кратны 1 Гц — бесшовная петля).
func _engine_jet() -> PackedFloat32Array:
	var n := MIX_RATE
	var fade := int(MIX_RATE * 0.1)
	var buf := PackedFloat32Array()
	buf.resize(n + fade)
	var y := 0.0
	for i in n + fade:
		var t := float(i) / MIX_RATE
		var white := _rng.randf_range(-1.0, 1.0)
		y += 0.1 * (white - y)
		buf[i] = y * 1.6 + sin(TAU * 110.0 * t) * 0.16 + sin(TAU * 220.0 * t) * 0.1 + sin(TAU * 1340.0 * t) * 0.035
	return _normalize(_make_loop(buf, fade), 0.8)


## Зацикленный стук поршневого/дизельного двигателя.
func _engine_pulse(rate_hz: float, noise_lp: float, tone_hz: float) -> PackedFloat32Array:
	var n := MIX_RATE
	var fade := int(MIX_RATE * 0.1)
	var buf := PackedFloat32Array()
	buf.resize(n + fade)
	var y := 0.0
	for i in n + fade:
		var t := float(i) / MIX_RATE
		var white := _rng.randf_range(-1.0, 1.0)
		y += noise_lp * (white - y)
		var pulse := pow(maxf(sin(TAU * rate_hz * t), 0.0), 6.0)
		buf[i] = y * (0.5 + pulse * 1.6) + sin(TAU * tone_hz * t) * 0.25 * (0.4 + pulse)
	return _normalize(_make_loop(buf, fade), 0.8)


## Зацикленный поршневой мотор с воздушным винтом: вспышки в цилиндрах (fire_hz), гармоники
## выхлопа, гул винта (prop_hz) и шум потока. rough — «неровность» (звездообразные моторы грубее).
func _engine_piston(fire_hz: float, prop_hz: float, rough: float) -> PackedFloat32Array:
	var n := MIX_RATE
	var fade := int(MIX_RATE * 0.1)
	var buf := PackedFloat32Array()
	buf.resize(n + fade)
	var y := 0.0
	var y2 := 0.0
	for i in n + fade:
		var t := float(i) / MIX_RATE
		var white := _rng.randf_range(-1.0, 1.0)
		y += 0.12 * (white - y)
		y2 += 0.02 * (white - y2)
		var fire := pow(maxf(sin(TAU * fire_hz * t), 0.0), 5.0)
		var hum := sin(TAU * fire_hz * 0.5 * t) * 0.34 + sin(TAU * fire_hz * t) * 0.26 + sin(TAU * fire_hz * 2.0 * t) * 0.1
		var prop := sin(TAU * prop_hz * t) * 0.18 + sin(TAU * prop_hz * 2.0 * t) * 0.07
		buf[i] = y * (0.35 + fire * 0.9 * rough) + y2 * 2.2 + hum * (0.55 + 0.45 * fire) + prop
	return _normalize(_make_loop(buf, fade), 0.8)


## Бесшовная петля: конец буфера плавно переходит в начало.
func _make_loop(buf: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := buf.size() - fade
	var out := buf.slice(0, n)
	for i in fade:
		var w := float(i) / float(fade)
		out[i] = buf[i] * w + buf[n + i] * (1.0 - w)
	return out
