extends Node
# 連線：ENet 直連。主機嘗試 UPnP 開埠，房間碼＝IP 編成 8 個符號。
signal got(kind: String, data)
signal peer_joined
signal peer_left
signal failed
const PORT = 24642
var active = false
var is_host = false
var other = 0
var upnp_ok = false
var public_ip = ""

func _ready() -> void:
	multiplayer.peer_connected.connect(func(id): other = id; peer_joined.emit())
	multiplayer.peer_disconnected.connect(func(_id): other = 0; peer_left.emit())
	multiplayer.connection_failed.connect(func(): active = false; failed.emit())
	multiplayer.server_disconnected.connect(func(): active = false; other = 0; peer_left.emit())

func host() -> Array:
	close()
	var p = ENetMultiplayerPeer.new()
	if p.create_server(PORT, 1) != OK: return []
	multiplayer.multiplayer_peer = p; active = true; is_host = true
	var ip = local_ip()
	var th = Thread.new(); th.start(_upnp.bind(th))
	return encode(ip)

func _upnp(th: Thread) -> void:
	var u = UPNP.new()
	if u.discover(1500, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS and u.get_gateway() and u.get_gateway().is_valid_gateway():
		if u.add_port_mapping(PORT, PORT, "luozha", "UDP") == UPNP.UPNP_RESULT_SUCCESS:
			var ext = u.query_external_address()
			call_deferred("_upnp_done", ext, th); return
	call_deferred("_upnp_done", "", th)

func _upnp_done(ext: String, th: Thread) -> void:
	th.wait_to_finish()
	if ext != "": upnp_ok = true; public_ip = ext; got.emit("code", encode(ext))

func join(code: Array) -> bool:
	close()
	var ip = decode(code)
	if ip == "": return false
	var p = ENetMultiplayerPeer.new()
	if p.create_client(ip, PORT) != OK: return false
	multiplayer.multiplayer_peer = p; active = true; is_host = false
	return true

func close() -> void:
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	active = false; other = 0; is_host = false

func local_ip() -> String:
	var best = "127.0.0.1"
	for a in IP.get_local_addresses():
		if a.count(".") != 3 or a.begins_with("127.") or a.begins_with("169.254"): continue
		if a.begins_with("192.168.") or a.begins_with("10."): return a
		best = a
	return best

func encode(ip: String) -> Array:
	var out = []
	for part in ip.split("."):
		var v = int(part); out.append(v >> 4); out.append(v & 15)
	return out

func decode(code: Array) -> String:
	if code.size() != 8: return ""
	var s = []
	for i in 4: s.append(str(int(code[i * 2]) * 16 + int(code[i * 2 + 1])))
	return ".".join(s)

func send(kind: String, data = null, reliable: bool = true) -> void:
	if not active or other == 0: return
	if reliable: _r.rpc_id(other, kind, data)
	else: _u.rpc_id(other, kind, data)

@rpc("any_peer", "call_remote", "reliable")
func _r(kind: String, data) -> void: got.emit(kind, data)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _u(kind: String, data) -> void: got.emit(kind, data)
