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

var peer: ENetMultiplayerPeer
var is_host: bool = false

# LAN Discovery Variables
var broadcaster: PacketPeerUDP
var listener: PacketPeerUDP
var broadcast_timer: float = 0.0
var found_servers: Array = []

func _ready() -> void:
	var ins_island = ISLAND_MANAGER.instantiate()
	#get_tree().current_scene.add_child(ins_island)
	
	var ins_ocean = STYLIZED_OCEAN.instantiate()
	get_tree().current_scene.add_child(ins_ocean)
	
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	# Automatically start listening for servers as soon as the game opens
	start_listening()

func _process(delta: float) -> void:
	# If we are the host, shout our existence to the network every 1 second
	if is_host and broadcaster != null:
		broadcast_timer += delta
		if broadcast_timer > 1.0:
			broadcaster.put_packet("PuffyPlaneServer".to_ascii_buffer())
			broadcast_timer = 0.0
			
	# If we are listening, check for incoming shouts
	if listener != null and listener.is_bound():
		while listener.get_available_packet_count() > 0:
			var packet = listener.get_packet().get_string_from_ascii()
			if packet == "PuffyPlaneServer":
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
	var error = peer.create_server(GAME_PORT, 8)
	if error != OK:
		print("Failed to host server: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	is_host = true
	print("Host started on port: ", GAME_PORT)
	
	# Stop listening and start broadcasting
	listener.close()
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_broadcast_enabled(true)
	broadcaster.set_dest_address("255.255.255.255", BROADCAST_PORT)
	
	# Spawn host player
	add_player(1)

func join_lobby(ip_address: String) -> void:
	# Stop listening for new servers once we join one
	listener.close()
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, GAME_PORT)
	if error != OK:
		print("Failed to join server: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	print("Connecting to host at: ", ip_address)
	%ui.hide()

# Server-side callback when a new client connects
func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	if multiplayer.is_server():
		add_player(id)

# Server-side callback when a client disconnects
func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	remove_player(id)

func _on_connected_to_server() -> void:
	print("Successfully connected to host.")

func _on_connection_failed() -> void:
	print("Failed to connect to host.")

func add_player(id: int) -> void:
	var player = player_scene.instantiate() as Player
	player.name = str(id)

	# Everyone spawns at the exact same spawn point now
	player.global_position = spawn_point.global_position
			
	call_deferred("add_child", player)

#func add_player(id: int) -> void:
	#var player = player_scene.instantiate() as Player
	#player.name = str(id)
#
	#if id == 1:
		#player.global_position = spawn_point.global_position
	#else:
		#if has_node("1"):
			#var host_node = get_node("1")
			#player.global_position = host_node.global_position + Vector3(0, 2, 0)
		#else:
			#player.global_position = spawn_point.global_position
			#
	#call_deferred("add_child", player)

func remove_player(id: int) -> void:
	if has_node(str(id)):
		get_node(str(id)).queue_free()

func _on_button_pressed() -> void:
	host_lobby()
	%ui.hide()
