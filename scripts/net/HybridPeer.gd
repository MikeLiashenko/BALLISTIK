class_name HybridPeer
extends MultiplayerPeerExtension
## Сетевой узел хоста: принимает игроков одновременно напрямую по UDP (ENet) и через резервный канал
## Firebase (FirebaseRelay). Для SceneMultiplayer это один сервер с id 1: пакеты обоих каналов идут
## в общую очередь, отправка выбирает канал по получателю (широковещательная — в оба).

const PEER_TIMEOUT := 20.0
const PING_INTERVAL := 3.0

var enet: ENetMultiplayerPeer = null
var relay: FirebaseRelay = null

var _relay_peers: Dictionary = {}
var _in: Array = []
var _target: int = 0
var _mode: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _channel: int = 0
var _last_poll: float = 0.0
var _ping_timer: float = 0.0


func _init(p_enet: ENetMultiplayerPeer, p_relay: FirebaseRelay) -> void:
	enet = p_enet
	relay = p_relay
	enet.peer_connected.connect(func(id: int) -> void: peer_connected.emit(id))
	enet.peer_disconnected.connect(func(id: int) -> void: peer_disconnected.emit(id))
	if relay != null:
		relay.packets.connect(_on_relay_packets)
		relay.control.connect(_on_relay_control)
	_last_poll = FirebaseRelay.now()


func relay_peer_count() -> int:
	return _relay_peers.size()


func is_relay_peer(id: int) -> bool:
	return _relay_peers.has(id)


func _on_relay_control(from: int, kind: String) -> void:
	match kind:
		"hello":
			relay.send_control(from, "ok")
			if not _relay_peers.has(from):
				_relay_peers[from] = FirebaseRelay.now()
				peer_connected.emit(from)
			else:
				_relay_peers[from] = FirebaseRelay.now()
		"bye":
			_drop(from)
		_:
			if _relay_peers.has(from):
				_relay_peers[from] = FirebaseRelay.now()


func _on_relay_packets(from: int, list: Array) -> void:
	if not _relay_peers.has(from):
		return
	_relay_peers[from] = FirebaseRelay.now()
	for e: Array in list:
		_in.append([from, int(e[0]), int(e[1]), e[2]])


func _drop(id: int) -> void:
	if _relay_peers.has(id):
		_relay_peers.erase(id)
		peer_disconnected.emit(id)


func _poll() -> void:
	var t := FirebaseRelay.now()
	var delta := t - _last_poll
	_last_poll = t
	enet.poll()
	if relay == null:
		return
	relay.poll(delta)
	_ping_timer += delta
	if _ping_timer > PING_INTERVAL:
		_ping_timer = 0.0
		for id: int in _relay_peers.keys():
			relay.send_control(id, "ping")
	for id: int in _relay_peers.keys():
		if t - float(_relay_peers[id]) > PEER_TIMEOUT:
			_drop(id)


func _get_available_packet_count() -> int:
	return _in.size() + enet.get_available_packet_count()


func _get_packet_peer() -> int:
	return int(_in[0][0]) if not _in.is_empty() else enet.get_packet_peer()


func _get_packet_channel() -> int:
	return int(_in[0][1]) if not _in.is_empty() else enet.get_packet_channel()


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return (int(_in[0][2]) if not _in.is_empty() else enet.get_packet_mode()) as MultiplayerPeer.TransferMode


func _get_packet_script() -> PackedByteArray:
	if not _in.is_empty():
		var e: Array = _in.pop_front()
		return e[3]
	return enet.get_packet()


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _target > 0 and _relay_peers.has(_target):
		relay.send(_target, _channel, _mode, buffer)
		return OK
	enet.transfer_mode = _mode as MultiplayerPeer.TransferMode
	enet.transfer_channel = _channel
	enet.set_target_peer(_target)
	var err := enet.put_packet(buffer)
	if _target <= 0 and relay != null:
		for id: int in _relay_peers.keys():
			if _target < 0 and id == -_target:
				continue
			relay.send(id, _channel, _mode, buffer)
	return err


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


func _set_target_peer(peer: int) -> void:
	_target = peer


func _is_server() -> bool:
	return true


func _get_unique_id() -> int:
	return 1


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return MultiplayerPeer.CONNECTION_CONNECTED


func _is_server_relay_supported() -> bool:
	return false


func _set_refuse_new_connections(enable: bool) -> void:
	enet.refuse_new_connections = enable


func _is_refusing_new_connections() -> bool:
	return enet.refuse_new_connections


func _disconnect_peer(peer: int, _force: bool) -> void:
	if _relay_peers.has(peer):
		relay.send_control(peer, "bye")
		_drop(peer)
	else:
		enet.disconnect_peer(peer, _force)


func _close() -> void:
	for id: int in _relay_peers.keys():
		relay.send_control(id, "bye")
	if relay != null:
		# Дать уйти последним «bye» (закрытие не ждёт ответа).
		relay.poll(1.0)
		relay.close()
	enet.close()
	_relay_peers.clear()
