class_name RelayPeer
extends MultiplayerPeerExtension
## Клиент сетевой игры через резервный канал Firebase: используется, когда до хоста не удалось
## достучаться напрямую по UDP. Для SceneMultiplayer выглядит как обычное подключение к серверу (id 1).

const CONNECT_TIMEOUT := 15.0
const HOST_TIMEOUT := 20.0
const PING_INTERVAL := 3.0

var relay: FirebaseRelay = null
var my_id: int = 0

var _status: int = MultiplayerPeer.CONNECTION_CONNECTING
var _in: Array = []
var _mode: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _channel: int = 0
var _started: float = 0.0
var _last_rx: float = 0.0
var _last_poll: float = 0.0
var _ping_timer: float = 0.0
var _hello_timer: float = 0.0


func _init(code: String) -> void:
	my_id = randi_range(2, 0x7FFFFFF0)
	relay = FirebaseRelay.new(code, my_id)
	relay.packets.connect(_on_packets)
	relay.control.connect(_on_control)
	relay.send_control(1, "hello")
	_started = FirebaseRelay.now()
	_last_poll = _started


func _on_control(from: int, kind: String) -> void:
	if from != 1:
		return
	_last_rx = FirebaseRelay.now()
	match kind:
		"ok":
			if _status == MultiplayerPeer.CONNECTION_CONNECTING:
				_status = MultiplayerPeer.CONNECTION_CONNECTED
				peer_connected.emit(1)
		"bye":
			_lost()


func _on_packets(from: int, list: Array) -> void:
	if from != 1 or _status != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_last_rx = FirebaseRelay.now()
	for e: Array in list:
		_in.append([int(e[0]), int(e[1]), e[2]])


func _lost() -> void:
	if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	var was := _status == MultiplayerPeer.CONNECTION_CONNECTED
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	if was:
		peer_disconnected.emit(1)


func _poll() -> void:
	var t := FirebaseRelay.now()
	var delta := t - _last_poll
	_last_poll = t
	relay.poll(delta)
	match _status:
		MultiplayerPeer.CONNECTION_CONNECTING:
			_hello_timer += delta
			if _hello_timer > 3.0:
				_hello_timer = 0.0
				relay.send_control(1, "hello")
			if t - _started > CONNECT_TIMEOUT:
				_status = MultiplayerPeer.CONNECTION_DISCONNECTED
		MultiplayerPeer.CONNECTION_CONNECTED:
			_ping_timer += delta
			if _ping_timer > PING_INTERVAL:
				_ping_timer = 0.0
				relay.send_control(1, "ping")
			if t - _last_rx > HOST_TIMEOUT:
				_lost()


func _get_available_packet_count() -> int:
	return _in.size()


func _get_packet_peer() -> int:
	return 1


func _get_packet_channel() -> int:
	return int(_in[0][0]) if not _in.is_empty() else 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return (int(_in[0][1]) if not _in.is_empty() else MultiplayerPeer.TRANSFER_MODE_RELIABLE) as MultiplayerPeer.TransferMode


func _get_packet_script() -> PackedByteArray:
	if _in.is_empty():
		return PackedByteArray()
	var e: Array = _in.pop_front()
	return e[2]


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	relay.send(1, _channel, _mode, buffer)
	return OK


func _get_max_packet_size() -> int:
	return 1 << 24


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode as MultiplayerPeer.TransferMode


func _set_target_peer(_peer: int) -> void:
	pass


func _is_server() -> bool:
	return false


func _get_unique_id() -> int:
	return my_id


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status as MultiplayerPeer.ConnectionStatus


func _is_server_relay_supported() -> bool:
	return false


func _set_refuse_new_connections(_enable: bool) -> void:
	pass


func _is_refusing_new_connections() -> bool:
	return true


func _disconnect_peer(_peer: int, _force: bool) -> void:
	_close()


func _close() -> void:
	if relay.closed:
		return
	relay.send_control(1, "bye")
	relay.poll(1.0)
	relay.close()
	_lost()
