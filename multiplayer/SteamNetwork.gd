extends Node

@onready var host_btn: Button = %Host
@onready var server_list: VBoxContainer = %server_list
@onready var spawn_point: Marker3D = %spawnPoint
@export var player_scene : PackedScene

const BOAT = preload("uid://i1deoi48p6g2")
const ISLAND_MANAGER = preload("uid://bwac1ripq0c8e")
const STYLIZED_OCEAN = preload("uid://c1kir5hwgtvdu")

const GAME_PORT: int = 8910
const BROADCAST_PORT: int = 8911
const MAX_PLAYER : int = 4

var peer: ENetMultiplayerPeer
var is_host: bool = false

var broadcaster: PacketPeerUDP
var listener: PacketPeerUDP
var broadcast_timer: float = 0.0
var found_servers: Array = []

func _ready() -> void:
	#var ins_island = ISLAND_MANAGER.instantiate()
	#get_tree().current_scene.add_child(ins_island)
	
	var ins_ocean = STYLIZED_OCEAN.instantiate()
	get_tree().current_scene.add_child(ins_ocean)
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	start_listening()

func _process(delta: float) -> void:

	if is_host and broadcaster != null:
		broadcast_timer += delta
		if broadcast_timer > 1.0:
			broadcaster.put_packet("CatsAway".to_ascii_buffer())
			broadcast_timer = 0.0

	if listener != null and listener.is_bound():
		while listener.get_available_packet_count() > 0:
			var packet = listener.get_packet().get_string_from_ascii()
			if packet == "CatsAway":
				var server_ip = listener.get_packet_ip()
				if not found_servers.has(server_ip):
					found_servers.append(server_ip)
					_create_server_button(server_ip)

#region LAN Discovery Functions
func start_listening() -> void:
	listener = PacketPeerUDP.new()
	var error = listener.bind(BROADCAST_PORT)
	if error != Error.OK:
		print("Failed to bind UDP listener.")

func _create_server_button(ip_address: String) -> void:
	var btn = Button.new()
	btn.text = "Join Server: " + ip_address
	btn.pressed.connect(func(): join_lobby(ip_address))
	server_list.add_child(btn)
	print("added button ", ip_address)
#endregion

func host_lobby() -> void:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(GAME_PORT, MAX_PLAYER)
	if error != OK:
		print("Failed to host server: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	is_host = true
	print("Host started on port: ", GAME_PORT)
	
	listener.close()
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_broadcast_enabled(true)
	broadcaster.set_dest_address("255.255.255.255", BROADCAST_PORT)

	spawn_player(1, spawn_point.global_position)

func join_lobby(ip_address: String) -> void:
	listener.close()
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, GAME_PORT)
	if error != OK:
		print("Failed to join server: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	print("Connecting to host at: ", ip_address)
	%ui.hide()

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	if multiplayer.is_server():
		# OLD
		# for child in get_children():
		# 	if child.name.is_valid_int():
		# 		rpc_id(id, "spawn_player", child.name.to_int(), child.global_position)

		for player_node in get_tree().get_nodes_in_group("player"):
			var existing_id = player_node.name.to_int()
			if existing_id > 0 and existing_id != id:
				rpc_id(id, "spawn_player", existing_id, player_node.global_position)

				if player_node.get_parent() != self:
					rpc_id(id, "sync_player_parent", existing_id, player_node.get_parent().get_path())

		rpc("spawn_player", id, spawn_point.global_position)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	if multiplayer.is_server():
		rpc("remove_player", id)

func _on_connected_to_server() -> void:
	print("Successfully connected to host.")

func _on_connection_failed() -> void:
	print("Failed to connect to host.")

@rpc("authority", "call_local", "reliable")
func spawn_player(id: int, spawn_pos: Vector3) -> void:
	var player = player_scene.instantiate()
	player.name = str(id)
	player.global_position = spawn_pos
	add_child(player)
	print(player.name, " : " ,player.global_position)

@rpc("authority", "call_remote", "reliable")
func sync_player_parent(player_id: int, parent_path: NodePath) -> void:
	var player_node = get_node_or_null(str(player_id))
	var parent_node = get_node_or_null(parent_path)
	if player_node and parent_node:
		player_node.reparent(parent_node, true)

@rpc("authority", "call_local", "reliable")
func remove_player(id: int) -> void:
	# OLD
	# if has_node(str(id)):
	# 	get_node(str(id)).queue_free()

	for player_node in get_tree().get_nodes_in_group("player"):
		if player_node.name == str(id):
			player_node.queue_free()
			break

func _on_button_pressed() -> void:
	host_lobby()
	%ui.hide()
