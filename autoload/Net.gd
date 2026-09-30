extends Node
## Сетевая игра BALLISTIK (Autoload «Net»): ENet (UDP) напрямую между устройствами, каталог комнат
## и матчмейкинг — в Firebase (NetDirectory).
##  * «Онлайн-бой» (как в War Thunder): поиск открытого боя с тем же режимом и эпохой; если такого нет —
##    устройство само становится хостом, ждёт игроков PUBLIC_WAIT секунд и начинает бой, свободные места
##    занимают боты. Подключаться можно и в идущий бой — игрок заменяет бота.
##  * «Комнаты»: хост создаёт комнату с кодом из 5 символов, друзья входят по коду; бой начинает хост.
##  * Хост — авторитет матча: боты, урон и ХП, очки, возрождение, сооружения. Каждый игрок сам
##    симулирует свою технику и 20 раз в секунду шлёт её состояние; чужая техника — «марионетки»
##    с интерполяцией. Снаряды повторяются визуальными копиями без урона; попадания своих снарядов
##    клиент сообщает хосту, ракеты/бомбы/торпеды взрываются у всех там, где взорвался оригинал.

signal status(text: String)
signal lobby_changed
signal session_ready
signal failed(reason: String)
signal closed(reason: String)

enum Mode { OFFLINE, HOST, CLIENT }

const PROTOCOL := 1
const PORT := 24680
const PORT_TRIES := 6
const MAX_CLIENTS := 31
const SNAP_INTERVAL := 0.05
const INTERP_DELAY := 0.12
const PUBLIC_WAIT := 25.0
const PUBLIC_REMATCH := 15.0
const HEARTBEAT := 10.0
const ENTRY := 17
const PROP_EXCLUDE := ["velocity", "age", "net_id", "net_visual"]

var mode: int = Mode.OFFLINE
## Параметры сессии: kind ("public"/"room"), code, name, ffa, era, map, difficulty, team_size,
## score_limit, time_min, state ("lobby"/"battle"/"ended").
var session: Dictionary = {}
var my_pid: int = -1
var directory: NetDirectory = null
## Последнее сообщение для меню (почему закрылась сессия).
var last_message: String = ""
var busy: bool = false
## Секунды до автостарта онлайн-боя (хост считает, клиенты получают).
var countdown: float = 0.0
var stats: Dictionary = {}

# Автотест двух процессов: --net-host[=ffa] [--net-wait=N] / --net-join=IP:PORT
var cli_host: bool = false
var cli_join: String = ""
var cli_wait: float = 10.0
var cli_started: bool = false
var cli_find: String = ""
var cli_relay_only: bool = false
var cli_cycle: bool = false

var _units: Dictionary = {}
var _next_unit_id: int = 1
var _proj: Dictionary = {}
var _proj_counter: int = 0
var _structs: Dictionary = {}
var _dirty_structs: Dictionary = {}
var _level_ready: bool = false
var _clock: Dictionary = {}
var _relay: Dictionary = {}
var _snap_timer: float = 0.0
var _struct_timer: float = 0.0
var _roster_dirty: bool = false
var _roster_timer: float = 0.0
var _heartbeat_timer: float = 0.0
var _dir_dirty: bool = false
var _out: Dictionary = {}
var _proto_ids: Dictionary = {}
var _proto_defs: Dictionary = {}
var _proto_sent: Dictionary = {}
var _proto_recv: Dictionary = {}
var _prop_cache: Dictionary = {}
var _class_paths: Dictionary = {}
var _sound_times: Dictionary = {}
var _end_timer: float = -1.0
var _welcome_ok: bool = false
var _join_error: String = ""
var _own: Vehicle = null
## Клиент подключён через резервный канал Firebase (а не напрямую).
var via_relay: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	directory = NetDirectory.new()
	directory.name = "Directory"
	add_child(directory)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	var gbm := GlobalBattleManager
	gbm.roster_changed.connect(func() -> void: _roster_dirty = true)
	gbm.score_changed.connect(func(_t: int, _s: int) -> void: _roster_dirty = true)
	gbm.kill_feed.connect(_on_kill_feed)
	gbm.announcement.connect(_on_announcement)
	gbm.match_ended.connect(_on_match_ended)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--net-host"):
			cli_host = true
			if arg.ends_with("=ffa"):
				GlobalBattleManager.ffa = true
		elif arg.begins_with("--net-join="):
			cli_join = arg.get_slice("=", 1)
		elif arg == "--net-cycle":
			cli_cycle = true
		elif arg == "--net-relay-only":
			cli_relay_only = true
		elif arg.begins_with("--net-find="):
			cli_find = arg.get_slice("=", 1)
		elif arg.begins_with("--net-wait="):
			cli_wait = maxf(float(arg.get_slice("=", 1)), 1.0)


## Закрытие окна: хост успевает убрать комнату из каталога и попрощаться с игроками.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if not active():
		get_tree().quit()
		return
	leave()
	await get_tree().create_timer(0.8, true, false, true).timeout
	get_tree().quit()


func active() -> bool:
	return mode != Mode.OFFLINE


func is_host() -> bool:
	return mode == Mode.HOST


func is_client() -> bool:
	return mode == Mode.CLIENT


func now() -> float:
	return Time.get_ticks_usec() * 0.000001


func my_peer() -> int:
	return multiplayer.get_unique_id() if active() else 1


func stat(key: String, amount: float = 1.0) -> void:
	stats[key] = float(stats.get(key, 0.0)) + amount


func unit_by_id(id: int) -> Vehicle:
	if id <= 0:
		return null
	var v: Variant = _units.get(id)
	if v != null and is_instance_valid(v):
		return v as Vehicle
	return null


func is_public() -> bool:
	return str(session.get("kind", "")) == "public"


# --- Сессия: хост ----------------------------------------------------------------------------------------
## Параметры новой сессии по умолчанию (из настроек игрока).
func default_session(kind: String, ffa: bool, era: int) -> Dictionary:
	var gs := GameSettings
	var s := {
		"kind": kind, "ffa": ffa, "era": era, "proto": PROTOCOL,
		"name": gs.player_name, "state": "lobby",
		"map": gs.map_id if kind == "room" else MapPresets.RANDOM_ID,
		"difficulty": gs.difficulty if kind == "room" else 1,
		"team_size": gs.team_size if kind == "room" else 8,
		"score_limit": gs.score_limit if kind == "room" else 1000,
		"time_min": gs.time_limit_min if kind == "room" else 15,
	}
	return s


## Стать хостом: открыть порт, собрать лобби (игрок + боты), опубликовать комнату.
func host_session(s: Dictionary, publish: bool = true) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := ERR_CANT_CREATE
	var port := PORT
	for i in PORT_TRIES:
		port = PORT + i
		err = peer.create_server(port, MAX_CLIENTS)
		if err == OK:
			break
	if err != OK:
		last_message = "Не удалось открыть сетевой порт %d" % PORT
		failed.emit(last_message)
		return false
	session = s.duplicate()
	session["port"] = port
	session["code"] = str(session.get("code", ""))
	if publish and str(session["code"]) == "":
		session["code"] = NetDirectory.random_code()
	if publish:
		# Хост принимает игроков и напрямую (UDP), и через резервный канал Firebase.
		multiplayer.multiplayer_peer = HybridPeer.new(peer, FirebaseRelay.new(str(session["code"]), 1))
	else:
		multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	my_pid = 1
	via_relay = false
	_reset_battle_state()
	GlobalBattleManager.apply_session(session)
	GlobalBattleManager.player_team = GameSettings.player_team
	GlobalBattleManager.prepare_lobby()
	countdown = PUBLIC_WAIT if is_public() else 0.0
	print("[NET] host: порт %d, режим %s, %s" % [port, str(session["kind"]), "ffa" if session.get("ffa") else "команды"])
	session_ready.emit()
	lobby_changed.emit()
	if publish:
		_publish_room()
	return true


func _publish_room() -> void:
	var code := str(session.get("code", ""))
	directory.open_port(int(session["port"]))
	var ok := await directory.publish(code, _room_card())
	if not ok and is_host():
		status.emit("Сервер комнат недоступен — друзья в локальной сети подключатся по адресу %s" % _lan_hint())
	# Когда станет известен внешний адрес — обновить карточку.
	for i in 40:
		if not is_host() or directory.upnp_done:
			break
		await get_tree().create_timer(0.25).timeout
	if is_host():
		directory.update(code, {"ip": directory.public_ip, "upnp": directory.upnp_mapped})


func _lan_hint() -> String:
	var lan := NetDirectory.lan_addresses()
	return "%s:%d" % [lan[0] if not lan.is_empty() else "127.0.0.1", int(session.get("port", PORT))]


func _room_card() -> Dictionary:
	return {
		"kind": session.get("kind", "room"), "ffa": session.get("ffa", false), "era": session.get("era", 0),
		"name": session.get("name", ""), "proto": PROTOCOL, "state": session.get("state", "lobby"),
		"humans": GlobalBattleManager.human_count(), "max": GlobalBattleManager.team_size * 2,
		"port": session.get("port", PORT), "lan": NetDirectory.lan_addresses(), "ip": directory.public_ip,
		"map": session.get("map", ""), "upnp": directory.upnp_mapped,
	}


## Изменение параметров комнаты хостом (карта, эпоха, размер, лимиты).
func set_session_value(key: String, value: Variant) -> void:
	if not is_host() or str(session.get("state", "")) != "lobby":
		return
	session[key] = value
	var gbm := GlobalBattleManager
	gbm.apply_session(session)
	if key == "era" or key == "team_size" or key == "ffa":
		_rebuild_bots()
	_broadcast_session()
	_roster_dirty = true
	_dir_dirty = true
	lobby_changed.emit()


## Пересобрать ботов под новые параметры, сохранив людей (их технику — если доступна в эпохе).
func _rebuild_bots() -> void:
	var gbm := GlobalBattleManager
	for p in gbm.participants.duplicate():
		if not p.is_human:
			gbm.release_slot(p)
			gbm.participants.erase(p)
		elif p.vehicle_type != "" and not gbm.is_available(p.vehicle_type):
			gbm.release_slot(p)
	var humans := [0, 0]
	for p in gbm.participants:
		humans[p.team] += 1
	gbm.team_size = maxi(gbm.team_size, maxi(humans[0], humans[1]))
	gbm._fill_bots()
	gbm.roster_changed.emit()


func _broadcast_session() -> void:
	if is_host():
		c_session.rpc(session, countdown)


## Хост начинает бой (вызывает GlobalBattleManager.start_battle): клиенты загружают ту же карту.
func host_match_starting(info: Dictionary) -> void:
	_reset_battle_state()
	session["state"] = "battle"
	_dir_dirty = true
	c_start.rpc(info)
	lobby_changed.emit()


func start_match() -> void:
	if not is_host() or str(session.get("state", "")) != "lobby":
		return
	var gbm := GlobalBattleManager
	if gbm.player != null and gbm.player.vehicle_type == "":
		var free := gbm.free_slot_types(gbm.player.team)
		if not free.is_empty():
			gbm.reserve_slot(gbm.player, free[0])
	gbm.start_battle()


## После матча — все обратно в лобби той же сессии.
func host_back_to_lobby() -> void:
	if not is_host():
		return
	session["state"] = "lobby"
	countdown = PUBLIC_WAIT if is_public() else 0.0
	_end_timer = -1.0
	_reset_battle_state()
	_dir_dirty = true
	c_back_to_lobby.rpc()
	_broadcast_session()
	GlobalBattleManager.return_to_lobby()


# --- Сессия: клиент ---------------------------------------------------------------------------------------
## Онлайн-бой: найти открытый бой с тем же режимом и эпохой или создать свой.
func find_match(ffa: bool, era: int) -> void:
	if busy:
		return
	busy = true
	leave()
	status.emit("Поиск боя…")
	var rooms := await directory.list_rooms()
	var cands: Array[Dictionary] = []
	for r in rooms:
		if str(r.get("kind", "")) != "public" or bool(r.get("ffa", false)) != ffa or int(r.get("era", 0)) != era:
			continue
		if int(r.get("proto", 0)) != PROTOCOL or str(r.get("state", "")) == "ended":
			continue
		if int(r.get("humans", 0)) >= int(r.get("max", 16)):
			continue
		cands.append(r)
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var la := 1 if str(a.get("state", "")) == "lobby" else 0
		var lb := 1 if str(b.get("state", "")) == "lobby" else 0
		if la != lb:
			return la > lb
		return int(a.get("humans", 0)) > int(b.get("humans", 0))
	)
	for r in cands.slice(0, 4):
		status.emit("Подключение к бою игрока %s…" % str(r.get("name", "?")))
		if await _join_room(r):
			busy = false
			return
	status.emit("Открытых боёв нет — создаём свой и ждём игроков…")
	busy = false
	host_session(default_session("public", ffa, era))


## Вход в комнату по коду (или напрямую по адресу IP[:порт]).
func join_code(text: String) -> void:
	if busy:
		return
	busy = true
	leave()
	var raw := text.strip_edges()
	if raw.count(".") == 3:
		var addr := raw if raw.contains(":") else "%s:%d" % [raw, PORT]
		status.emit("Подключение к %s…" % addr)
		if not await _connect_and_join([addr]):
			_fail(_join_error if _join_error != "" else "Не удалось подключиться к %s" % addr)
		busy = false
		return
	var code := NetDirectory.normalize_code(raw)
	if code.length() != NetDirectory.CODE_LEN:
		busy = false
		_fail("Код комнаты — %d символов" % NetDirectory.CODE_LEN)
		return
	status.emit("Поиск комнаты %s…" % code)
	var room := await directory.get_room(code)
	if room.is_empty():
		busy = false
		_fail("Комната %s не найдена (или хост вышел)" % code)
		return
	if int(room.get("proto", 0)) != PROTOCOL:
		busy = false
		_fail("У хоста другая версия игры")
		return
	if not await _join_room(room):
		_fail(_join_error if _join_error != "" else "Хост комнаты недоступен из этой сети (нужен проброс порта %d / UPnP)" % int(room.get("port", PORT)))
	busy = false


func _fail(reason: String) -> void:
	last_message = reason
	failed.emit(reason)


func _join_room(room: Dictionary) -> bool:
	var cands := NetDirectory.connect_candidates(room)
	if not cands.is_empty() and not cli_relay_only and await _connect_and_join(cands):
		return true
	if _join_error != "" or str(room.get("code", "")) == "":
		return false
	# Прямое подключение не удалось — резервный канал через сервер комнат.
	status.emit("Прямое подключение не удалось — подключаемся через сервер (задержка выше)…")
	var peer := RelayPeer.new(str(room["code"]))
	multiplayer.multiplayer_peer = peer
	var limit := now() + RelayPeer.CONNECT_TIMEOUT + 1.0
	while now() < limit and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		await get_tree().create_timer(0.1).timeout
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		peer.close()
		multiplayer.multiplayer_peer = null
		return false
	via_relay = true
	return await _handshake("сервер комнат")


func _connect_and_join(addrs: Array) -> bool:
	_join_error = ""
	for a: String in addrs:
		var ip := a.get_slice(":", 0)
		var port := int(a.get_slice(":", 1)) if a.contains(":") else PORT
		var local := ip == "127.0.0.1" or ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172.")
		var peer := ENetMultiplayerPeer.new()
		if peer.create_client(ip, port) != OK:
			continue
		multiplayer.multiplayer_peer = peer
		var limit := now() + (2.5 if local else 6.0)
		while now() < limit and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
			await get_tree().create_timer(0.1).timeout
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			peer.close()
			multiplayer.multiplayer_peer = null
			continue
		via_relay = false
		if await _handshake(a):
			return true
		if _join_error != "":
			return false
	return false


## Подключение установлено — представиться хосту и дождаться приёма в сессию.
func _handshake(where: String) -> bool:
	mode = Mode.CLIENT
	_welcome_ok = false
	_reset_battle_state()
	h_hello.rpc_id(1, GameSettings.player_name, PROTOCOL)
	var wait_until := now() + (20.0 if via_relay else 8.0)
	while now() < wait_until and mode == Mode.CLIENT and not _welcome_ok and _join_error == "":
		await get_tree().create_timer(0.1).timeout
	if _welcome_ok:
		print("[NET] client: подключён (%s), участник %d" % [where, my_pid])
		return true
	leave()
	return false


## Выйти из сетевой игры (хост закрывает комнату).
func leave() -> void:
	if mode == Mode.OFFLINE:
		return
	if is_host():
		var code := str(session.get("code", ""))
		directory.remove(code)
		if code != "":
			directory.request(HTTPClient.METHOD_DELETE, "/ballistik/v1/relay/" + code)
		directory.close_port()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	mode = Mode.OFFLINE
	session = {}
	my_pid = -1
	countdown = 0.0
	_reset_battle_state()
	GlobalBattleManager.ffa = false
	lobby_changed.emit()


func _reset_battle_state() -> void:
	_units.clear()
	_proj.clear()
	_structs.clear()
	_dirty_structs.clear()
	_relay.clear()
	_out.clear()
	_proto_ids.clear()
	_proto_defs.clear()
	_proto_sent.clear()
	_proto_recv.clear()
	_level_ready = false
	_next_unit_id = 1
	_proj_counter = 0


func request_slot(type_id: String) -> void:
	if is_client():
		h_slot.rpc_id(1, type_id)


func request_team(team: int) -> void:
	if is_client():
		h_team.rpc_id(1, team)


func request_recall() -> void:
	if is_client():
		h_recall.rpc_id(1)


# --- Подключения ------------------------------------------------------------------------------------------
func _on_peer_connected(id: int) -> void:
	if is_host():
		print("[NET] пир %d подключился" % id)


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	var p := GlobalBattleManager.participant_by_peer(id)
	if p != null:
		var who := p.name
		GlobalBattleManager.remove_remote_human(id)
		GlobalBattleManager.kill_feed.emit("%s покинул бой" % who, Color(0.7, 0.75, 0.8))
	_proto_sent.erase(id)
	_out.erase(id)
	_clock.erase(id)
	_dir_dirty = true
	lobby_changed.emit()


func _on_server_disconnected() -> void:
	var reason := "Соединение с хостом потеряно"
	_close_with(reason)


func _close_with(reason: String) -> void:
	last_message = reason
	var in_battle := GlobalBattleManager.level != null
	leave()
	closed.emit(reason)
	if GlobalBattleManager.smoke_test:
		print("[NET] сессия закрыта: ", reason)
		GlobalBattleManager.print_net_summary()
		get_tree().quit(0)
		return
	if in_battle:
		GlobalBattleManager.return_to_menu()


# --- RPC: лобби -------------------------------------------------------------------------------------------
@rpc("any_peer", "call_remote", "reliable")
func h_hello(p_name: String, proto: int) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if proto != PROTOCOL:
		c_reject.rpc_id(id, "У хоста другая версия игры")
		return
	var clean := p_name.strip_edges().left(18)
	if clean == "":
		clean = "Пилот"
	var p := GlobalBattleManager.add_remote_human(id, clean)
	if p == null:
		c_reject.rpc_id(id, "Все места в бою заняты")
		return
	c_welcome.rpc_id(id, p.id, session, GlobalBattleManager.net_roster_rows(), countdown)
	if str(session.get("state", "")) == "battle":
		c_start.rpc_id(id, GlobalBattleManager.net_match_info())
	GlobalBattleManager.kill_feed.emit("%s присоединился" % clean, Color(0.5, 0.9, 1.0))
	if is_public() and str(session.get("state", "")) == "lobby" and GlobalBattleManager.human_count() >= GlobalBattleManager.team_size * 2:
		countdown = minf(countdown, 3.0)
	_roster_dirty = true
	_dir_dirty = true
	lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func c_reject(reason: String) -> void:
	_join_error = reason


@rpc("authority", "call_remote", "reliable")
func c_welcome(pid: int, s: Dictionary, rows: Array, cd: float) -> void:
	my_pid = pid
	session = s
	countdown = cd
	var gbm := GlobalBattleManager
	gbm.participants.clear()
	gbm.player = null
	gbm.apply_session(s)
	gbm.net_apply_roster(rows, pid)
	_welcome_ok = true
	session_ready.emit()
	lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func c_session(s: Dictionary, cd: float) -> void:
	session = s
	countdown = cd
	GlobalBattleManager.apply_session(s)
	lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func c_roster(rows: Array, sc: Array, t_left: float, cd: float) -> void:
	countdown = cd
	GlobalBattleManager.net_apply_roster(rows, my_pid)
	GlobalBattleManager.net_apply_scores(sc, t_left)
	lobby_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func h_slot(type_id: String) -> void:
	var p := GlobalBattleManager.participant_by_peer(multiplayer.get_remote_sender_id())
	if is_host() and p != null:
		GlobalBattleManager.request_slot_for(p, type_id)
		_roster_dirty = true


@rpc("any_peer", "call_remote", "reliable")
func h_team(team: int) -> void:
	var p := GlobalBattleManager.participant_by_peer(multiplayer.get_remote_sender_id())
	if is_host() and p != null and str(session.get("state", "")) == "lobby" and not GlobalBattleManager.ffa:
		GlobalBattleManager.move_to_team(p, clampi(team, 0, 1))
		_roster_dirty = true


@rpc("any_peer", "call_remote", "reliable")
func h_recall() -> void:
	var p := GlobalBattleManager.participant_by_peer(multiplayer.get_remote_sender_id())
	if is_host() and p != null and p.has_live_vehicle():
		p.vehicle.despawn()


@rpc("authority", "call_remote", "reliable")
func c_start(info: Dictionary) -> void:
	session["state"] = "battle"
	_reset_battle_state()
	lobby_changed.emit()
	GlobalBattleManager.net_begin_match(info)


@rpc("authority", "call_remote", "reliable")
func c_back_to_lobby() -> void:
	session["state"] = "lobby"
	_reset_battle_state()
	GlobalBattleManager.return_to_lobby()


@rpc("authority", "call_remote", "reliable")
func c_match_end(w: int, rows: Array, sc: Array) -> void:
	session["state"] = "ended"
	GlobalBattleManager.net_apply_roster(rows, my_pid)
	GlobalBattleManager.net_apply_scores(sc, 0.0)
	GlobalBattleManager.net_finish(w)


# --- Уровень и мир ----------------------------------------------------------------------------------------
## Уровень загружен: у клиента — просьба прислать мир, у хоста — отправка мира готовым клиентам.
func on_level_ready(level: BattleLevel) -> void:
	_structs.clear()
	for b in GlobalBattleManager.structures:
		if is_instance_valid(b):
			_structs[b.net_key] = b
	_level_ready = true
	if is_client():
		h_level_ready.rpc_id(1)
	elif is_host():
		for p in GlobalBattleManager.participants:
			if p.is_human and not p.is_player and p.net_ready:
				_send_world(p.peer_id)
	if level != null:
		print("[NET] уровень готов: %d сооружений" % _structs.size())


@rpc("any_peer", "call_remote", "reliable")
func h_level_ready() -> void:
	var id := multiplayer.get_remote_sender_id()
	var p := GlobalBattleManager.participant_by_peer(id)
	if not is_host() or p == null:
		return
	p.net_ready = true
	if _level_ready:
		_send_world(id)


func _send_world(peer_id: int) -> void:
	if not _peer_ok(peer_id):
		return
	_proto_sent.erase(peer_id)
	for id: int in _units.keys():
		var v := unit_by_id(id)
		if v != null and not v.is_dead:
			c_spawn.rpc_id(peer_id, _spawn_info(v))
	var keys := PackedInt32Array()
	var hps := PackedFloat32Array()
	for key: int in _structs.keys():
		var b: Building = _structs[key]
		if is_instance_valid(b) and b.health < b.max_health:
			keys.append(key)
			hps.append(b.health)
	if not keys.is_empty():
		c_struct_hp.rpc_id(peer_id, keys, hps)
	c_roster.rpc_id(peer_id, GlobalBattleManager.net_roster_rows(), GlobalBattleManager.scores, GlobalBattleManager.time_left, countdown)


func make_structure_key(kind: String, pos: Vector3) -> int:
	return hash("%s:%d:%d" % [kind, roundi(pos.x), roundi(pos.z)]) & 0x3FFFFFFF


# --- Юниты ------------------------------------------------------------------------------------------------
## Новый юнит на уровне: хост назначает сетевой id и сообщает клиентам.
func on_unit_added(v: Vehicle) -> void:
	if not is_host():
		return
	v.net_id = _next_unit_id
	_next_unit_id += 1
	_units[v.net_id] = v
	if _level_ready:
		c_spawn.rpc(_spawn_info(v))


func _spawn_info(v: Vehicle) -> Dictionary:
	return {
		"id": v.net_id, "type": v.vehicle_type, "team": v.team, "pid": v.participant_id, "name": v.pilot_name,
		"owner": v.net_owner, "human": v.is_human, "xf": v.global_transform, "hp": v.health,
		"auto": v is Warship and (v as Warship).autonomous,
	}


@rpc("authority", "call_remote", "reliable")
func c_spawn(d: Dictionary) -> void:
	var level := GlobalBattleManager.level
	var id := int(d["id"])
	if not _level_ready or level == null or unit_by_id(id) != null:
		return
	var v := GlobalBattleManager.create_vehicle(str(d["type"]))
	v.net_id = id
	v.team = int(d["team"])
	v.participant_id = int(d["pid"])
	v.pilot_name = str(d["name"])
	v.net_owner = int(d["owner"])
	v.is_human = bool(d["human"])
	v.is_player = v.net_owner == my_peer()
	v.net_puppet = not v.is_player
	if v is Warship and bool(d.get("auto", false)):
		(v as Warship).autonomous = true
	v.transform = d["xf"]
	var gbm := GlobalBattleManager
	var bot_driven := v.is_player and gbm.smoke_test and not gbm.smoke_human
	if bot_driven:
		v.add_child(BotAI.new())
	_units[id] = v
	level.add_unit(v)
	var hp := float(d.get("hp", v.max_health))
	if hp < v.max_health:
		v.net_set_health(hp)
	if v is Warship and (v as Warship).autonomous:
		level.warships.append(v as Warship)
	var p := gbm.get_participant(v.participant_id)
	if p != null:
		p.vehicle = v
		p.alive = true
	stat("spawns")
	if v.is_player:
		_own = v
		level.on_player_spawned(v, bot_driven)
		gbm.player_spawned.emit(v)
	gbm.unit_spawned.emit(v)


func on_unit_destroyed(v: Vehicle, killer: Dictionary) -> void:
	if not is_host() or v.net_id == 0:
		return
	_units.erase(v.net_id)
	_relay.erase(v.net_id)
	c_unit_dead.rpc(v.net_id, v.participant_id, _clean_source(killer))


func on_unit_despawned(v: Vehicle) -> void:
	if not is_host() or v.net_id == 0:
		return
	_units.erase(v.net_id)
	_relay.erase(v.net_id)
	c_despawn.rpc(v.net_id, v.participant_id)


@rpc("authority", "call_remote", "reliable")
func c_unit_dead(id: int, pid: int, killer: Dictionary) -> void:
	if not _level_ready:
		return
	var gbm := GlobalBattleManager
	var v := unit_by_id(id)
	_units.erase(id)
	if v != null:
		if int(killer.get("attacker_id", -1)) == my_pid and my_pid >= 0 and v.participant_id != my_pid:
			gbm.player_hit.emit(v, 0.0, true)
		gbm.unit_destroyed.emit(v, killer)
		v.net_kill(killer)
	var p := gbm.get_participant(pid)
	if p != null:
		p.alive = false
		p.vehicle = null
	if pid == my_pid:
		gbm.player_died.emit(killer)


@rpc("authority", "call_remote", "reliable")
func c_despawn(id: int, pid: int) -> void:
	if not _level_ready:
		return
	var v := unit_by_id(id)
	_units.erase(id)
	if v != null:
		v.net_despawn()
	if pid == my_pid:
		GlobalBattleManager.player_died.emit({"recall": true})


## Клиент: своя техника разбилась (земля, вода) — сообщить хосту.
func request_self_destroy(v: Vehicle, killer: Dictionary) -> void:
	if is_client() and _level_ready and v.net_id != 0:
		h_destroy.rpc_id(1, v.net_id, _clean_source(killer))


@rpc("any_peer", "call_remote", "reliable")
func h_destroy(id: int, _killer: Dictionary) -> void:
	var v := unit_by_id(id)
	if is_host() and v != null and v.net_owner == multiplayer.get_remote_sender_id():
		v.destroy({})


# --- Снимки состояния ------------------------------------------------------------------------------------
func _send_snapshots() -> void:
	var t := now()
	if is_host():
		var out := PackedFloat32Array()
		for id: int in _units.keys():
			var v := unit_by_id(id)
			if v == null or v.is_dead:
				continue
			if v.net_puppet:
				var r: Variant = _relay.get(id)
				if r == null:
					continue
				var raw: PackedFloat32Array = r[0]
				raw[14] = v.health
				out.append_array(raw)
				out.append(t - float(r[1]))
			else:
				v.net_write_state(out)
				out.append(0.0)
		if not out.is_empty():
			c_snap.rpc(t, out)
	elif is_client():
		if _own != null and is_instance_valid(_own) and not _own.is_dead:
			var out := PackedFloat32Array()
			_own.net_write_state(out)
			out.append(0.0)
			h_snap.rpc_id(1, t, out)


## Оценка сдвига часов отправителя: local ≈ remote + offset (минимальная задержка, медленный дрейф).
func _to_local(sender: int, ts: float) -> float:
	var sample := now() - ts
	var off: float = _clock.get(sender, sample)
	if sample < off:
		off = sample
	else:
		off += (sample - off) * 0.01
	_clock[sender] = off
	return ts + off


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func c_snap(ts: float, d: PackedFloat32Array) -> void:
	if not _level_ready:
		return
	stat("snaps_rx")
	var base := _to_local(1, ts)
	var i := 0
	while i + ENTRY <= d.size():
		var v := unit_by_id(int(d[i]))
		if v != null and not v.is_dead:
			if v.net_puppet:
				v.net_push_state(base - d[i + 16], d, i)
			v.net_set_health(d[i + 14])
		i += ENTRY


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func h_snap(ts: float, d: PackedFloat32Array) -> void:
	if not is_host() or not _level_ready:
		return
	var sender := multiplayer.get_remote_sender_id()
	var base := _to_local(sender, ts)
	stat("snaps_rx")
	var i := 0
	while i + ENTRY <= d.size():
		var id := int(d[i])
		var v := unit_by_id(id)
		if v != null and not v.is_dead and v.net_owner == sender:
			var t := base - d[i + 16]
			v.net_push_state(t, d, i)
			_relay[id] = [d.slice(i, i + 16), t]
		i += ENTRY


# --- Урон ------------------------------------------------------------------------------------------------
## Клиент: попадание своего снаряда (или повреждение своей техники) — хосту.
func forward_damage(target: Node, amount: float, damage_type: String, source: Dictionary) -> void:
	if not _level_ready:
		return
	var attacker := int(source.get("attacker_id", -1))
	var own := target is Vehicle and not (target as Vehicle).net_puppet
	if attacker != my_pid and not (own and attacker < 0):
		return
	var ref := _ref_of(target)
	if ref == 0:
		return
	h_damage.rpc_id(1, ref, amount, damage_type, _clean_source(source))
	stat("damage_tx")
	if attacker == my_pid and not own:
		GlobalBattleManager.report_damage(target, amount, source)


@rpc("any_peer", "call_remote", "reliable")
func h_damage(ref: int, amount: float, damage_type: String, source: Dictionary) -> void:
	if not is_host() or not _level_ready:
		return
	var sender := multiplayer.get_remote_sender_id()
	var p := GlobalBattleManager.participant_by_peer(sender)
	var target := _node_of(ref)
	if p == null or target == null or amount <= 0.0:
		return
	var src := source
	if int(source.get("attacker_id", -1)) >= 0:
		src = {"team": p.team, "attacker_id": p.id, "attacker_name": p.name, "vehicle_label": str(source.get("vehicle_label", "")), "weapon": str(source.get("weapon", "")), "bot": false}
	elif not (target is Vehicle and (target as Vehicle).net_owner == sender):
		return
	stat("damage_rx")
	target.call("apply_damage", minf(amount, 5000.0), damage_type, src)


func _clean_source(s: Dictionary) -> Dictionary:
	var out := {}
	for k: String in ["team", "attacker_id", "attacker_name", "vehicle_label", "weapon", "bot", "recall"]:
		if s.has(k):
			out[k] = s[k]
	return out


func _ref_of(node: Object) -> int:
	if node is Vehicle:
		return (node as Vehicle).net_id
	if node is Building:
		return -(node as Building).net_key - 1
	return 0


func _node_of(ref: int) -> Node3D:
	if ref > 0:
		return unit_by_id(ref)
	if ref < 0:
		var b: Variant = _structs.get(-ref - 1)
		if b != null and is_instance_valid(b) and not (b as Building).is_dead:
			return b as Building
	return null


# --- Сооружения ------------------------------------------------------------------------------------------
func mark_structure_dirty(b: Building) -> void:
	if is_host() and _level_ready:
		_dirty_structs[b.net_key] = b


func on_structure_destroyed(b: Building, killer: Dictionary) -> void:
	if is_host() and _level_ready:
		_dirty_structs.erase(b.net_key)
		c_struct_dead.rpc(b.net_key, _clean_source(killer))


@rpc("authority", "call_remote", "reliable")
func c_struct_hp(keys: PackedInt32Array, hps: PackedFloat32Array) -> void:
	if not _level_ready:
		return
	for i in keys.size():
		var b: Variant = _structs.get(keys[i])
		if b != null and is_instance_valid(b):
			if hps[i] <= 0.0:
				(b as Building).net_destroy({})
			else:
				(b as Building).net_set_health(hps[i])


@rpc("authority", "call_remote", "reliable")
func c_struct_dead(key: int, killer: Dictionary) -> void:
	if not _level_ready:
		return
	var b: Variant = _structs.get(key)
	if b == null or not is_instance_valid(b):
		return
	if int(killer.get("attacker_id", -1)) == my_pid and my_pid >= 0:
		GlobalBattleManager.player_hit.emit(b, 0.0, true)
	(b as Building).net_destroy(killer)


# --- Лента, объявления, конец матча (хост → клиенты) ---------------------------------------------------------
func _on_kill_feed(text: String, color: Color) -> void:
	if is_host():
		c_feed.rpc(text, color)


func _on_announcement(text: String, color: Color) -> void:
	if is_host() and _level_ready:
		c_announce.rpc(text, color)


func _on_match_ended(w: int) -> void:
	if not is_host():
		return
	session["state"] = "ended"
	_dir_dirty = true
	c_match_end.rpc(w, GlobalBattleManager.net_roster_rows(), GlobalBattleManager.scores)
	if is_public():
		_end_timer = PUBLIC_REMATCH


@rpc("authority", "call_remote", "reliable")
func c_feed(text: String, color: Color) -> void:
	GlobalBattleManager.kill_feed.emit(text, color)


@rpc("authority", "call_remote", "reliable")
func c_announce(text: String, color: Color) -> void:
	if _level_ready:
		GlobalBattleManager.announcement.emit(text, color)


# --- Снаряды ---------------------------------------------------------------------------------------------
## Снаряд выпущен на этом устройстве: разослать копии (хост — всем клиентам, клиент — хосту).
func on_projectile_spawned(node: Node3D) -> void:
	if not active() or not _level_ready or not (node is Projectile):
		return
	var p := node as Projectile
	if p.net_visual:
		return
	if p.net_tracked():
		_proj_counter = (_proj_counter + 1) & 0xFFFFF
		p.net_id = ((my_pid if is_client() else 0) << 20) | _proj_counter
		if p.net_id == 0:
			p.net_id = 1
		_proj[p.net_id] = p
	for r in _recipients():
		_queue_projectile(r, p)


func _peer_ok(id: int) -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(id)


func _recipients(exclude: int = 0) -> Array[int]:
	var result: Array[int] = []
	if is_client():
		result.append(1)
		return result
	for p in GlobalBattleManager.participants:
		if p.is_human and not p.is_player and p.net_ready and p.peer_id != exclude and _peer_ok(p.peer_id):
			result.append(p.peer_id)
	return result


func _prop_names(p: Projectile) -> Array:
	var path: String = p.get_script().resource_path
	if _prop_cache.has(path):
		return _prop_cache[path]
	var names: Array = []
	for prop: Dictionary in p.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n := str(prop["name"])
		if n.begins_with("_") or PROP_EXCLUDE.has(n):
			continue
		if int(prop["type"]) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR3, TYPE_COLOR]:
			names.append(n)
	_prop_cache[path] = names
	return names


func _proto_of(p: Projectile) -> int:
	var cls := str(p.get_script().get_global_name())
	var d := {"c": cls, "pid": p.owner_pid()}
	var vals: Array = [cls, p.owner_pid()]
	for n: String in _prop_names(p):
		var val: Variant = p.get(n)
		d[n] = val
		vals.append(val)
	var key := str(vals)
	if _proto_ids.has(key):
		return int(_proto_ids[key])
	var id := _proto_ids.size() + 1
	_proto_ids[key] = id
	_proto_defs[id] = d
	return id


func _queue_projectile(r: int, p: Projectile) -> void:
	var proto := _proto_of(p)
	var b: Dictionary = _out.get(r, {})
	if b.is_empty():
		b = {"defs": {}, "i": PackedInt32Array(), "f": PackedFloat32Array()}
		_out[r] = b
	var sent: Dictionary = _proto_sent.get(r, {})
	if not sent.has(proto):
		sent[proto] = true
		_proto_sent[r] = sent
		(b["defs"] as Dictionary)[proto] = _proto_defs[proto]
	var ints: PackedInt32Array = b["i"]
	ints.append_array(PackedInt32Array([proto, _ref_of(p.shooter) if is_instance_valid(p.shooter) else 0, _target_ref(p), p.net_id]))
	b["i"] = ints
	var fl: PackedFloat32Array = b["f"]
	var pos := p.global_position
	fl.append_array(PackedFloat32Array([pos.x, pos.y, pos.z, p.velocity.x, p.velocity.y, p.velocity.z]))
	b["f"] = fl


func _target_ref(p: Projectile) -> int:
	for key: String in ["target", "target_node"]:
		if key in p:
			var t: Variant = p.get(key)
			if t != null and is_instance_valid(t) and (t is Vehicle or t is Building):
				return _ref_of(t)
	return 0


func _flush_projectiles() -> void:
	for r: int in _out.keys():
		var b: Dictionary = _out[r]
		if (b["i"] as PackedInt32Array).is_empty():
			continue
		x_proj.rpc_id(r, b)
		stat("proj_tx", (b["i"] as PackedInt32Array).size() / 4.0)
	_out.clear()


@rpc("any_peer", "call_remote", "reliable", 2)
func x_proj(b: Dictionary) -> void:
	if not _level_ready or GlobalBattleManager.level == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var known: Dictionary = _proto_recv.get(sender, {})
	var defs: Dictionary = b.get("defs", {})
	for k: Variant in defs.keys():
		known[int(k)] = defs[k]
	_proto_recv[sender] = known
	var ints: PackedInt32Array = b.get("i", PackedInt32Array())
	var fl: PackedFloat32Array = b.get("f", PackedFloat32Array())
	var n := mini(ints.size() / 4, fl.size() / 6)
	for k in n:
		var proto: Variant = known.get(ints[k * 4])
		if proto == null:
			continue
		var copy := _make_projectile(proto, ints, fl, k)
		if copy != null and is_host():
			for r in _recipients(sender):
				_queue_projectile(r, copy)


func _make_projectile(proto: Dictionary, ints: PackedInt32Array, fl: PackedFloat32Array, k: int) -> Projectile:
	var script := _script_for(str(proto.get("c", "Projectile")))
	if script == null:
		return null
	var p: Projectile = script.new()
	for key: String in proto.keys():
		if key != "c" and key != "pid":
			p.set(key, proto[key])
	var pid := int(proto.get("pid", -1))
	var shooter := unit_by_id(ints[k * 4 + 1])
	p.setup(int(proto.get("team", -1)), {"team": int(proto.get("team", -1)), "attacker_id": pid, "weapon": "сеть"}, shooter)
	p.net_visual = true
	p.net_id = ints[k * 4 + 3]
	var target := _node_of(ints[k * 4 + 2])
	if target != null:
		if p is Torpedo:
			if target is Vehicle:
				(p as Torpedo).target = target as Vehicle
		elif "target" in p:
			p.set("target", target)
		elif "target_node" in p:
			p.set("target_node", target)
	p.position = Vector3(fl[k * 6], fl[k * 6 + 1], fl[k * 6 + 2])
	p.velocity = Vector3(fl[k * 6 + 3], fl[k * 6 + 4], fl[k * 6 + 5])
	if p.net_id != 0:
		_proj[p.net_id] = p
	GlobalBattleManager.level.spawn_projectile(p)
	_remote_fire_sound(p, ints[k * 4 + 1])
	stat("proj_rx")
	return p


func _script_for(cls: String) -> Script:
	if _class_paths.is_empty():
		for c: Dictionary in ProjectSettings.get_global_class_list():
			_class_paths[str(c["class"])] = str(c["path"])
	if not _class_paths.has(cls):
		return null
	var s: Variant = load(str(_class_paths[cls]))
	return s as Script


## Звук выстрела для копии снаряда (у оригинала его проигрывает оружие).
func _remote_fire_sound(p: Projectile, shooter_ref: int) -> void:
	var cls := str(p.get_script().get_global_name())
	var t := now()
	if cls == "Projectile":
		if t - float(_sound_times.get(shooter_ref, 0.0)) < 0.11:
			return
		_sound_times[shooter_ref] = t
		var key := "cannon" if p.blast_radius > 6.0 else ("cannon_air" if p.damage >= 10.0 else "mg")
		SoundFX.play_3d(key, p.position, -5.0, 1.0, 26.0 + p.blast_radius * 2.0)
	elif cls == "Rocket":
		SoundFX.play_3d("missile", p.position, -6.0, 1.4, 25.0)
	elif cls == "Bomb":
		SoundFX.play_3d("bomb_release", p.position, -4.0, 1.0, 20.0)


## Владелец: отслеживаемый боеприпас закончил полёт.
func on_projectile_end(p: Projectile, kind: int) -> void:
	_proj.erase(p.net_id)
	if not active() or not _level_ready:
		return
	for r in _recipients():
		x_proj_end.rpc_id(r, p.net_id, p.global_position, kind)


@rpc("any_peer", "call_remote", "reliable", 2)
func x_proj_end(id: int, pos: Vector3, kind: int) -> void:
	if not _level_ready:
		return
	var p: Variant = _proj.get(id)
	_proj.erase(id)
	if p != null and is_instance_valid(p):
		(p as Projectile).net_end(pos, kind)
	if is_host():
		for r in _recipients(multiplayer.get_remote_sender_id()):
			x_proj_end.rpc_id(r, id, pos, kind)


## Владелец: ракета потеряла цель (ушла на ловушку) — у копий снимается предупреждение о ракете.
func on_projectile_lost(p: Projectile) -> void:
	if not active() or not _level_ready:
		return
	for r in _recipients():
		x_proj_lost.rpc_id(r, p.net_id)


@rpc("any_peer", "call_remote", "reliable", 2)
func x_proj_lost(id: int) -> void:
	if not _level_ready:
		return
	var p: Variant = _proj.get(id)
	if p != null and is_instance_valid(p):
		(p as Projectile).net_lose_target()
	if is_host():
		for r in _recipients(multiplayer.get_remote_sender_id()):
			x_proj_lost.rpc_id(r, id)


## Копию чужой ракеты сбила ПВО корабля — перехват выполняет владелец ракеты.
func request_intercept(p: Projectile) -> void:
	if not active() or p.net_id == 0:
		return
	var slot := p.net_id >> 20
	if is_client():
		x_intercept.rpc_id(1, p.net_id)
	elif slot > 0:
		var owner := GlobalBattleManager.get_participant(slot)
		if owner != null and owner.is_human and not owner.is_player:
			x_intercept.rpc_id(owner.peer_id, p.net_id)


@rpc("any_peer", "call_remote", "reliable", 2)
func x_intercept(id: int) -> void:
	var p: Variant = _proj.get(id)
	if p != null and is_instance_valid(p):
		var proj := p as Projectile
		if not proj.net_visual:
			proj.intercept()
		elif is_host():
			request_intercept(proj)


# --- Ловушки ---------------------------------------------------------------------------------------------
func send_flare(v: Vehicle, pos: Vector3, vel: Vector3, decoy: bool) -> void:
	if not active() or not _level_ready or v.net_puppet or v.net_id == 0:
		return
	for r in _recipients():
		x_flare.rpc_id(r, v.net_id, pos, vel, decoy)


@rpc("any_peer", "call_remote", "reliable", 2)
func x_flare(id: int, pos: Vector3, vel: Vector3, decoy: bool) -> void:
	if not _level_ready:
		return
	var parent := GlobalBattleManager.get_fx_parent()
	var v := unit_by_id(id)
	if parent != null:
		var f := Flare.new()
		f.velocity = vel
		f.position = pos
		parent.add_child(f)
		if decoy and v is Aircraft:
			(v as Aircraft).net_flare_decoy(f)
	if is_host():
		for r in _recipients(multiplayer.get_remote_sender_id()):
			x_flare.rpc_id(r, id, pos, vel, decoy)


# --- Цикл -----------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not active():
		return
	var gbm := GlobalBattleManager
	if _level_ready and gbm.match_running:
		_snap_timer += delta
		if _snap_timer >= SNAP_INTERVAL:
			_snap_timer = fmod(_snap_timer, SNAP_INTERVAL)
			_send_snapshots()
		_flush_projectiles()
	if not is_host():
		if countdown > 0.0:
			countdown = maxf(countdown - delta, 0.0)
		return
	_roster_timer += delta
	var periodic := _roster_timer > 1.0
	if (_roster_dirty and _roster_timer > 0.15) or periodic:
		_roster_timer = 0.0
		_roster_dirty = false
		c_roster.rpc(gbm.net_roster_rows(), gbm.scores, gbm.time_left, countdown)
	_struct_timer += delta
	if _struct_timer > 0.5 and not _dirty_structs.is_empty():
		_struct_timer = 0.0
		var keys := PackedInt32Array()
		var hps := PackedFloat32Array()
		for key: int in _dirty_structs.keys():
			var b: Building = _dirty_structs[key]
			if is_instance_valid(b) and not b.is_dead:
				keys.append(key)
				hps.append(b.health)
		_dirty_structs.clear()
		if not keys.is_empty():
			c_struct_hp.rpc(keys, hps)
	# Онлайн-бой: автостарт после ожидания игроков, после матча — снова в лобби.
	var state := str(session.get("state", ""))
	if is_public() and state == "lobby" and not cli_host:
		countdown -= delta
		if countdown <= 0.0:
			countdown = 0.0
			start_match()
	if _end_timer > 0.0:
		_end_timer -= delta
		if _end_timer <= 0.0:
			host_back_to_lobby()
	_heartbeat_timer += delta
	var code := str(session.get("code", ""))
	if code != "" and (_heartbeat_timer > HEARTBEAT or (_dir_dirty and _heartbeat_timer > 1.0)):
		_heartbeat_timer = 0.0
		_dir_dirty = false
		directory.update(code, {"humans": gbm.human_count(), "max": gbm.team_size * 2, "state": session.get("state", "lobby"), "era": session.get("era", 0), "ffa": session.get("ffa", false), "ip": directory.public_ip, "lan": NetDirectory.lan_addresses(), "port": session.get("port", PORT)})


# --- Автотест двух процессов -------------------------------------------------------------------------------
## Хост: комната без публикации, ждёт cli_wait секунд и начинает бой. Клиент: входит по адресу.
func start_cli_test() -> void:
	var gbm := GlobalBattleManager
	if cli_find != "":
		# Полный путь через каталог комнат: поиск открытого боя или создание своего.
		await find_match(cli_find == "ffa", gbm.air_era)
		print("[NET] тест поиска: ", "хост" if is_host() else ("клиент" if is_client() else "ошибка: " + last_message))
		if is_client():
			_cli_client_loop()
		return
	if cli_host:
		var s := default_session("room", gbm.ffa, gbm.air_era)
		s["team_size"] = 4
		s["map"] = gbm.smoke_map if gbm.smoke_map != "" else "coast"
		host_session(s, false)
		var free := gbm.free_slot_types(gbm.player.team)
		if gbm.smoke_vehicle != "":
			gbm.request_slot_for(gbm.player, GameDB.resolve_id(gbm.smoke_vehicle))
		elif not free.is_empty():
			gbm.reserve_slot(gbm.player, free[0])
		print("[NET] тест: хост ждёт %.0f с" % cli_wait)
		await get_tree().create_timer(cli_wait).timeout
		start_match()
		if cli_cycle:
			# Конец матча → лобби → новый бой (как в онлайн-бою после матча).
			await get_tree().create_timer(25.0).timeout
			print("[NET] тест: принудительный конец матча")
			gbm._finish_match(-1)
			await get_tree().create_timer(3.0).timeout
			host_back_to_lobby()
			await get_tree().create_timer(5.0).timeout
			print("[NET] тест: второй бой")
			start_match()
	elif cli_join != "":
		var ok := false
		for attempt in 10:
			if await _connect_and_join([cli_join]):
				ok = true
				break
			await get_tree().create_timer(1.0).timeout
		if not ok:
			print("[NET] тест: не удалось подключиться к ", cli_join)
			get_tree().quit(1)
			return
		_cli_client_loop()


func _cli_client_loop() -> void:
	var gbm := GlobalBattleManager
	while is_client():
		if gbm.player != null and not gbm.player.alive and gbm.player.vehicle_type == "":
			var wanted := GameDB.resolve_id(gbm.smoke_vehicle) if gbm.smoke_vehicle != "" else ""
			var free := gbm.free_slot_types(gbm.player.team)
			if wanted != "" and gbm.is_available(wanted):
				request_slot(wanted)
			elif not free.is_empty():
				request_slot(free[randi() % free.size()])
		await get_tree().create_timer(1.0).timeout


func summary() -> String:
	var keys := stats.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		parts.append("%s=%d" % [str(k), int(stats[k])])
	return "[NET] %s units=%d peers=%d %s" % ["host" if is_host() else ("client" if is_client() else "offline"), _units.size(), multiplayer.get_peers().size() if active() else 0, " ".join(parts)]


## Выход из игры с закрытием сессии (комната удаляется из каталога).
func quit_after_leave(exit_code: int = 0) -> void:
	var was_active := active()
	leave()
	if was_active:
		await get_tree().create_timer(0.8, true, false, true).timeout
	get_tree().quit(exit_code)
