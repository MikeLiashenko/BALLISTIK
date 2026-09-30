class_name NetDirectory
extends Node
## Каталог сетевых боёв в Firebase Realtime Database (REST): хосты публикуют комнаты с кодом и адресами,
## клиенты находят их по коду или подбирают открытый бой (матчмейкинг). Сам бой идёт напрямую между
## устройствами по UDP (ENet); база хранит только карточки комнат.
##  * /ballistik/v1/rooms/<КОД> — {kind, ffa, era, name, humans, max, state, proto, addrs, updated};
##  * хост обновляет карточку каждые 10 с («пульс»), карточки без пульса дольше 45 с считаются мёртвыми
##    и удаляются клиентами при просмотре списка;
##  * порт хоста открывается через UPnP роутера, внешний адрес — от роутера или api.ipify.org.

const DB_URL := "https://bolthub-88d22-default-rtdb.asia-southeast1.firebasedatabase.app"
const ROOMS := "/ballistik/v1/rooms"
const CLOCK := "/ballistik/v1/clock"
const STALE_MS := 45000.0
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LEN := 5

## Внешний (публичный) IPv4 этого устройства ("" — неизвестен) и открыт ли порт через UPnP.
var public_ip: String = ""
var upnp_mapped: bool = false
var upnp_done: bool = false

var _offset_ms: float = 0.0
var _offset_known: bool = false
var _upnp: Object = null
var _upnp_thread: Thread = null
var _upnp_port: int = 0


# --- HTTP ---------------------------------------------------------------------------------------------
## Запрос к базе: {"ok": bool, "data": Variant, "error": String}.
func request(method: int, path: String, body: Variant = null) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	var payload := JSON.stringify(body) if body != null else ""
	var err := http.request(DB_URL + path + ".json", PackedStringArray(["Content-Type: application/json"]), method, payload)
	if err != OK:
		http.queue_free()
		return {"ok": false, "data": null, "error": "HTTP %d" % err}
	var res: Array = await http.request_completed
	http.queue_free()
	var code := int(res[1])
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "data": null, "error": "нет связи с сервером комнат"}
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	if code >= 300:
		return {"ok": false, "data": null, "error": "сервер комнат: %d" % code}
	return {"ok": true, "data": JSON.parse_string(text) if text != "" else null, "error": ""}


static func local_ms() -> float:
	return Time.get_unix_time_from_system() * 1000.0


## Время сервера (мс) — по нему проверяется свежесть карточек.
func server_ms() -> float:
	return local_ms() + _offset_ms


func _ensure_offset() -> void:
	if _offset_known:
		return
	var key := "c%d" % (randi() % 1000000)
	var t0 := local_ms()
	var r := await request(HTTPClient.METHOD_PUT, CLOCK + "/" + key, {".sv": "timestamp"})
	var t1 := local_ms()
	if r["ok"] and (r["data"] is float or r["data"] is int):
		_offset_ms = float(r["data"]) - (t0 + t1) * 0.5
		_offset_known = true
	request(HTTPClient.METHOD_DELETE, CLOCK + "/" + key)


# --- Комнаты ------------------------------------------------------------------------------------------
static func random_code() -> String:
	var s := ""
	for i in CODE_LEN:
		s += CODE_CHARS[randi() % CODE_CHARS.length()]
	return s


static func normalize_code(text: String) -> String:
	var out := ""
	for ch in text.strip_edges().to_upper():
		if CODE_CHARS.contains(ch):
			out += ch
	return out


## Свободный код комнаты (проверка, что такого ещё нет).
func new_code() -> String:
	for attempt in 5:
		var code := random_code()
		var r := await request(HTTPClient.METHOD_GET, ROOMS + "/" + code)
		if r["ok"] and r["data"] == null:
			return code
		if not r["ok"]:
			return code
	return random_code()


func publish(code: String, room: Dictionary) -> bool:
	var body := room.duplicate()
	body["updated"] = {".sv": "timestamp"}
	var r := await request(HTTPClient.METHOD_PUT, ROOMS + "/" + code, body)
	return bool(r["ok"])


## Обновление карточки (пульс, число игроков, состояние, адреса).
func update(code: String, fields: Dictionary) -> void:
	var body := fields.duplicate()
	body["updated"] = {".sv": "timestamp"}
	await request(HTTPClient.METHOD_PATCH, ROOMS + "/" + code, body)


func remove(code: String) -> void:
	if code != "":
		await request(HTTPClient.METHOD_DELETE, ROOMS + "/" + code)


## Карточка комнаты по коду ({} — нет такой или она устарела).
func get_room(code: String) -> Dictionary:
	await _ensure_offset()
	var r := await request(HTTPClient.METHOD_GET, ROOMS + "/" + code)
	if not r["ok"] or not (r["data"] is Dictionary):
		return {}
	var room: Dictionary = r["data"]
	if _is_stale(room):
		return {}
	room["code"] = code
	return room


## Все живые комнаты; устаревшие карточки удаляются.
func list_rooms() -> Array[Dictionary]:
	await _ensure_offset()
	var result: Array[Dictionary] = []
	var r := await request(HTTPClient.METHOD_GET, ROOMS)
	if not r["ok"] or not (r["data"] is Dictionary):
		return result
	var all: Dictionary = r["data"]
	for code: String in all.keys():
		var room: Variant = all[code]
		if not (room is Dictionary):
			continue
		if _is_stale(room):
			if server_ms() - float((room as Dictionary).get("updated", 0.0)) > STALE_MS * 3.0:
				request(HTTPClient.METHOD_DELETE, ROOMS + "/" + code)
				request(HTTPClient.METHOD_DELETE, "/ballistik/v1/relay/" + code)
			continue
		(room as Dictionary)["code"] = code
		result.append(room)
	return result


func _is_stale(room: Dictionary) -> bool:
	return server_ms() - float(room.get("updated", 0.0)) > STALE_MS


# --- Адреса -------------------------------------------------------------------------------------------
## Адреса IPv4 этого устройства в локальных сетях.
static func lan_addresses() -> Array[String]:
	var result: Array[String] = []
	for a in IP.get_local_addresses():
		if not a.is_valid_ip_address() or a.contains(":"):
			continue
		if a.begins_with("10.") or a.begins_with("192.168.") or _is_172_private(a):
			result.append(a)
	return result


static func _is_172_private(a: String) -> bool:
	if not a.begins_with("172."):
		return false
	var second := int(a.get_slice(".", 1))
	return second >= 16 and second <= 31


static func _subnet(a: String) -> String:
	return a.substr(0, a.rfind("."))


## Порядок подключения к комнате: тот же компьютер, общая локальная сеть, затем внешний адрес.
static func connect_candidates(room: Dictionary) -> Array[String]:
	var mine := lan_addresses()
	var nets := {}
	for a in mine:
		nets[_subnet(a)] = true
	var result: Array[String] = []
	var addrs: Array = room.get("lan", [])
	var port := int(room.get("port", 24680))
	for a: String in addrs:
		if mine.has(a):
			result.push_front("127.0.0.1:%d" % port)
		elif nets.has(_subnet(a)):
			result.append("%s:%d" % [a, port])
	var pub := str(room.get("ip", ""))
	if pub != "":
		result.append("%s:%d" % [pub, port])
	return result


## Открыть порт на роутере (UPnP) и узнать внешний адрес — в фоновом потоке.
func open_port(port: int) -> void:
	upnp_done = false
	upnp_mapped = false
	_upnp_port = port
	if not ClassDB.class_exists("UPNP"):
		_fetch_public_ip()
		return
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(port))


func _upnp_work(port: int) -> Dictionary:
	var u: Object = ClassDB.instantiate("UPNP")
	var err := int(u.call("discover", 1500, 2, "InternetGatewayDevice"))
	if err != 0:
		return {"upnp": null}
	var gw: Object = u.call("get_gateway")
	if gw == null or not bool(gw.call("is_valid_gateway")):
		return {"upnp": null}
	var ip := str(u.call("query_external_address"))
	var mapped := int(u.call("add_port_mapping", port, port, "BALLISTIK", "UDP", 0)) == 0
	return {"upnp": u, "ip": ip, "mapped": mapped}


func _process(_delta: float) -> void:
	if _upnp_thread != null and not _upnp_thread.is_alive():
		var res: Dictionary = _upnp_thread.wait_to_finish()
		_upnp_thread = null
		_upnp = res.get("upnp")
		upnp_mapped = bool(res.get("mapped", false))
		var ip := str(res.get("ip", ""))
		if ip.is_valid_ip_address() and not ip.contains(":"):
			public_ip = ip
			upnp_done = true
		else:
			_fetch_public_ip()


func _fetch_public_ip() -> void:
	var http := HTTPRequest.new()
	http.timeout = 6.0
	add_child(http)
	if http.request("https://api.ipify.org") == OK:
		var res: Array = await http.request_completed
		var text := (res[3] as PackedByteArray).get_string_from_utf8().strip_edges()
		if int(res[0]) == HTTPRequest.RESULT_SUCCESS and text.is_valid_ip_address() and not text.contains(":"):
			public_ip = text
	http.queue_free()
	upnp_done = true


## Закрыть проброс порта (при выходе из комнаты).
func close_port() -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if _upnp != null and upnp_mapped:
		_upnp.call("delete_port_mapping", _upnp_port, "UDP")
	_upnp = null
	upnp_mapped = false


func _exit_tree() -> void:
	close_port()
