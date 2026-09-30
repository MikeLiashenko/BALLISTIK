class_name FirebaseRelay
extends RefCounted
## Резервный канал сетевой игры через Firebase Realtime Database — когда прямое UDP-соединение
## невозможно (роутер без UPnP, мобильный интернет, CGNAT). Медленнее прямого (сотни мс), но работает
## за любым роутером.
##  * у каждого участника свой «почтовый ящик» /ballistik/v1/relay/<КОД>/<id>; его содержимое приходит
##    потоком Server-Sent Events (одно постоянное HTTPS-соединение);
##  * исходящие пакеты копятся и уходят пачками одним PATCH на несколько ящиков сразу (до трёх запросов
##    параллельно); у пачки номер — получатель обрабатывает пачки строго по порядку;
##  * ненадёжные пакеты (снимки состояния) в пачке заменяют предыдущие того же канала — отправляется
##    только самое свежее состояние;
##  * прочитанные сообщения удаляются из ящика.

signal packets(from_id: int, list: Array)
signal control(from_id: int, kind: String)

const HOST := "bolthub-88d22-default-rtdb.asia-southeast1.firebasedatabase.app"
const ROOT := "/ballistik/v1/relay/"
const WRITERS := 3
const MIN_FLUSH := 0.06
const HOLD_TIMEOUT := 3.0

var code: String = ""
var my_id: int = 0
var closed: bool = false
var bytes_out: int = 0
var bytes_in: int = 0

var _stream: HTTPClient = null
var _stream_path: String = ""
var _stream_host: String = HOST
var _stream_requested: bool = false
var _stream_buf: PackedByteArray = PackedByteArray()
var _stream_retry: float = 0.0
var _writers: Array[Dictionary] = []
var _outbox: Dictionary = {}
var _seq: Dictionary = {}
var _recv_next: Dictionary = {}
var _recv_hold: Dictionary = {}
var _hold_since: Dictionary = {}
var _consumed: Array[String] = []
var _last_flush: float = 0.0
var _last_cleanup: float = 0.0
var _retry: Array = []


func _init(p_code: String, p_id: int) -> void:
	code = p_code
	my_id = p_id
	_stream_path = ROOT + code + "/" + str(my_id) + ".json"
	for i in WRITERS:
		_writers.append({"http": HTTPClient.new(), "busy": false, "body": "", "path": "", "sent": false})


static func now() -> float:
	return Time.get_ticks_usec() * 0.000001


# --- Отправка ---------------------------------------------------------------------------------------------
func send(to_id: int, channel: int, mode: int, data: PackedByteArray) -> void:
	var box: Array = _outbox.get(to_id, [])
	if mode != MultiplayerPeer.TRANSFER_MODE_RELIABLE:
		for i in range(box.size() - 1, -1, -1):
			var e: Array = box[i]
			if e[0] == "p" and int(e[1]) == channel and int(e[2]) != MultiplayerPeer.TRANSFER_MODE_RELIABLE:
				box.remove_at(i)
				break
	box.append(["p", channel, mode, data])
	_outbox[to_id] = box


func send_control(to_id: int, kind: String) -> void:
	var box: Array = _outbox.get(to_id, [])
	box.append(["c", kind])
	_outbox[to_id] = box


func has_pending() -> bool:
	return not _outbox.is_empty()


func _flush() -> void:
	if _outbox.is_empty() or now() - _last_flush < MIN_FLUSH:
		return
	var w := _idle_writer()
	if w.is_empty():
		return
	var body := {}
	for to_id: int in _outbox.keys():
		var buf := StreamPeerBuffer.new()
		var ctl := ""
		for e: Array in _outbox[to_id]:
			if e[0] == "c":
				ctl = str(e[1]) if ctl == "" else ctl + "," + str(e[1])
				continue
			var data: PackedByteArray = e[3]
			buf.put_u8(int(e[1]))
			buf.put_u8(int(e[2]))
			buf.put_u32(data.size())
			buf.put_data(data)
		var s := int(_seq.get(to_id, 0)) + 1
		_seq[to_id] = s
		var msg := {"f": my_id, "s": s}
		if buf.get_size() > 0:
			msg["d"] = Marshalls.raw_to_base64(buf.data_array)
		if ctl != "":
			msg["c"] = ctl
		body["%d/%012d_%d" % [to_id, s, my_id]] = msg
	_outbox.clear()
	_last_flush = now()
	var text := JSON.stringify(body)
	bytes_out += text.length()
	_start_request(w, HTTPClient.METHOD_PATCH, ROOT + code + ".json", text)


func _idle_writer() -> Dictionary:
	for w in _writers:
		if not bool(w["busy"]):
			return w
	return {}


func _start_request(w: Dictionary, method: int, path: String, body: String) -> void:
	w["busy"] = true
	w["method"] = method
	w["path"] = path
	w["body"] = body
	w["sent"] = false
	w["t"] = now()


func _poll_writer(w: Dictionary) -> void:
	var http: HTTPClient = w["http"]
	http.poll()
	var st := http.get_status()
	if not bool(w["busy"]):
		return
	match st:
		HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			if bool(w["sent"]):
				_retry.append([int(w["method"]), str(w["path"]), str(w["body"])])
				w["busy"] = false
			http.close()
			http.connect_to_host(HOST, 443, TLSOptions.client())
		HTTPClient.STATUS_CONNECTED:
			if not bool(w["sent"]):
				http.request(int(w["method"]), str(w["path"]), PackedStringArray(["Content-Type: application/json", "Connection: keep-alive"]), str(w["body"]))
				w["sent"] = true
			elif not http.has_response():
				w["busy"] = false
		HTTPClient.STATUS_BODY:
			http.read_response_body_chunk()
			if http.get_status() != HTTPClient.STATUS_BODY:
				w["busy"] = false


# --- Приём ------------------------------------------------------------------------------------------------
func _poll_stream(delta: float) -> void:
	if _stream == null:
		_stream_retry -= delta
		if _stream_retry > 0.0:
			return
		_stream = HTTPClient.new()
		_stream.read_chunk_size = 65536
		_stream.connect_to_host(_stream_host, 443, TLSOptions.client())
		_stream_requested = false
		_stream_buf.clear()
	_stream.poll()
	match _stream.get_status():
		HTTPClient.STATUS_CONNECTED:
			if not _stream_requested:
				_stream.request(HTTPClient.METHOD_GET, _stream_path, PackedStringArray(["Accept: text/event-stream"]))
				_stream_requested = true
			elif _stream.has_response() and _stream.get_response_code() == 307:
				_redirect(_location())
			else:
				_restart_stream(0.5)
		HTTPClient.STATUS_BODY:
			var code_http := _stream.get_response_code()
			if code_http == 307:
				_redirect(_location())
				return
			if code_http >= 300:
				_restart_stream(2.0)
				return
			for i in 8:
				var chunk := _stream.read_response_body_chunk()
				if chunk.is_empty():
					break
				_stream_buf.append_array(chunk)
				bytes_in += chunk.size()
			_parse_events()
		HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_restart_stream(1.0)


func _location() -> String:
	var h := _stream.get_response_headers_as_dictionary()
	for k: Variant in h.keys():
		if str(k).to_lower() == "location":
			return str(h[k])
	return ""


func _redirect(url: String) -> void:
	var rest := url.replace("https://", "")
	var slash := rest.find("/")
	if slash > 0:
		_stream_host = rest.substr(0, slash)
		_stream_path = rest.substr(slash)
	_restart_stream(0.0)


func _restart_stream(wait: float) -> void:
	if _stream != null:
		_stream.close()
	_stream = null
	_stream_retry = wait


## Разбор событий SSE: «event: put|patch» + «data: {"path": ..., "data": ...}».
func _parse_events() -> void:
	while true:
		var text := _stream_buf.get_string_from_utf8()
		var end := text.find("\n\n")
		if end < 0:
			return
		var ev := text.substr(0, end)
		var used := ev.to_utf8_buffer().size() + 2
		_stream_buf = _stream_buf.slice(used)
		var kind := ""
		var data := ""
		for line in ev.split("\n"):
			if line.begins_with("event:"):
				kind = line.substr(6).strip_edges()
			elif line.begins_with("data:"):
				data = line.substr(5).strip_edges()
		if kind != "put" and kind != "patch":
			continue
		var parsed: Variant = JSON.parse_string(data)
		if not (parsed is Dictionary):
			continue
		var path := str((parsed as Dictionary).get("path", "/"))
		var payload: Variant = (parsed as Dictionary).get("data")
		if payload == null:
			continue
		if path == "/":
			if payload is Dictionary:
				var keys: Array = (payload as Dictionary).keys()
				keys.sort()
				for k: String in keys:
					_accept(k, (payload as Dictionary)[k])
		else:
			_accept(path.trim_prefix("/"), payload)


func _accept(key: String, msg: Variant) -> void:
	if not (msg is Dictionary):
		return
	var m: Dictionary = msg
	_consumed.append(key)
	var from := int(m.get("f", 0))
	var s := int(m.get("s", 0))
	if from == 0:
		return
	var next := int(_recv_next.get(from, 1))
	if s < next:
		return
	var hold: Dictionary = _recv_hold.get(from, {})
	hold[s] = m
	_recv_hold[from] = hold
	_drain(from)


func _drain(from: int) -> void:
	var hold: Dictionary = _recv_hold.get(from, {})
	var next := int(_recv_next.get(from, 1))
	while hold.has(next):
		_deliver(from, hold[next])
		hold.erase(next)
		next += 1
	_recv_next[from] = next
	if hold.is_empty():
		_hold_since.erase(from)
	elif not _hold_since.has(from):
		_hold_since[from] = now()


func _deliver(from: int, m: Dictionary) -> void:
	if m.has("c"):
		for kind in str(m["c"]).split(","):
			control.emit(from, kind)
	if m.has("d"):
		var raw := Marshalls.base64_to_raw(str(m["d"]))
		var buf := StreamPeerBuffer.new()
		buf.data_array = raw
		var list: Array = []
		while buf.get_position() + 6 <= raw.size():
			var ch := buf.get_u8()
			var mode := buf.get_u8()
			var n := buf.get_u32()
			var res: Array = buf.get_data(n)
			if int(res[0]) != OK:
				break
			list.append([ch, mode, res[1] as PackedByteArray])
		if not list.is_empty():
			packets.emit(from, list)


## Пропуск потерянной пачки (запрос на запись не дошёл за HOLD_TIMEOUT).
func _check_holds() -> void:
	for from: int in _hold_since.keys():
		if now() - float(_hold_since[from]) < HOLD_TIMEOUT:
			continue
		var hold: Dictionary = _recv_hold.get(from, {})
		if hold.is_empty():
			continue
		var keys: Array = hold.keys()
		keys.sort()
		_recv_next[from] = int(keys[0])
		_hold_since.erase(from)
		_drain(from)


func _cleanup() -> void:
	if _consumed.is_empty() or now() - _last_cleanup < 2.0:
		return
	var w := _idle_writer()
	if w.is_empty():
		return
	var body := {}
	for k in _consumed:
		body[k] = null
	_consumed.clear()
	_last_cleanup = now()
	_start_request(w, HTTPClient.METHOD_PATCH, ROOT + code + "/" + str(my_id) + ".json", JSON.stringify(body))


# --- Цикл ------------------------------------------------------------------------------------------------
func poll(delta: float) -> void:
	if closed:
		return
	_poll_stream(delta)
	for w in _writers:
		_poll_writer(w)
	if not _retry.is_empty():
		var w := _idle_writer()
		if not w.is_empty():
			var r: Array = _retry.pop_front()
			_start_request(w, int(r[0]), str(r[1]), str(r[2]))
	_flush()
	_check_holds()
	_cleanup()


func close() -> void:
	closed = true
	if _stream != null:
		_stream.close()
	for w in _writers:
		(w["http"] as HTTPClient).close()
