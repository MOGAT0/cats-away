#WaterMath.gd a singleton script
extends Node

# --- NEW: Dynamic Coast Transition Settings ---
var deep_sea_height : float = 0.8
var deep_sea_choppy : float = 4.0
var coast_height : float = 0.5
var coast_choppy : float = 0.5

# How far away from the island's edge the water starts calming down
var coast_blend_distance : float = 250.0 

# The active variables used by the physics math
var sea_height : float = 0.8
var sea_choppy : float = 4.0
var sea_speed : float = 1.5
var sea_freq : float = 0.08

var water_level_global_y : float = 0.0 
var tracked_position : Vector3 = Vector3.ZERO # The player will update this
var current_ocean_material : ShaderMaterial = null # Used to sync the visual shader

const OCTAVE_M := Transform2D(Vector2(1.6, 1.2), Vector2(-1.2, 1.6), Vector2.ZERO)
const STYLIZED_OCEAN = preload("res://ocean simulation/stylized_ocean.tres")

func _ready() -> void:
	# Assuming your material is in surface 0, or material_override. 
	# Adjust this line depending on where your ShaderMaterial is assigned!
	var mat = STYLIZED_OCEAN
	
	# Hand the material to the singleton
	WaterMath.current_ocean_material = mat

func _process(_delta: float) -> void:
	# 1. Find the nearest island
	var nearest_dist = INF
	var nearest_island_radius = 0.0
	
	for key in IslandManager.island_data:
		var data = IslandManager.island_data[key]
		var i_pos = data["position"]
		var i_size = data["size"]
		
		# 2D distance check (ignoring Y axis so deep water doesn't mess it up)
		var dist = Vector2(tracked_position.x, tracked_position.z).distance_to(Vector2(i_pos.x, i_pos.z))
		
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_island_radius = i_size / 2.0
			
	# 2. Calculate Blend Weight (0.0 = Deep Sea, 1.0 = Coast)
	var blend_weight = 0.0
	if nearest_dist != INF:
		# Calculate distance from the actual edge of the island, not the center
		var distance_from_edge = nearest_dist - nearest_island_radius
		
		if distance_from_edge <= 0.0:
			blend_weight = 1.0 # Player is inside/directly on the island
		elif distance_from_edge < coast_blend_distance:
			# Smoothstep gives a perfectly natural, ease-in/ease-out transition
			var norm = 1.0 - (distance_from_edge / coast_blend_distance)
			blend_weight = smoothstep(0.0, 1.0, norm)
			
	# 3. Lerp the physics values
	sea_height = lerp(deep_sea_height, coast_height, blend_weight)
	sea_choppy = lerp(deep_sea_choppy, coast_choppy, blend_weight)
	
	# 4. Sync visual shader instantly
	if current_ocean_material:
		current_ocean_material.set_shader_parameter("sea_height", sea_height)
		current_ocean_material.set_shader_parameter("sea_choppy", sea_choppy)

# ... (Keep all your existing hash12, noise, sea_octave, and get_water_height functions below here)

# Translates the GLSL bitwise hash to Godot's 64-bit integers, masking to 32-bit
func hash12(p: Vector2) -> float:
	var qx: int = (int(p.x) * 1597334677) & 0xFFFFFFFF
	var qy: int = (int(p.y) * 3812015801) & 0xFFFFFFFF
	var n: int = ((qx ^ qy) * 1597334677) & 0xFFFFFFFF
	return float(n) / 4294967295.0

func noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	
	var a = lerp(hash12(i + Vector2(0.0, 0.0)), hash12(i + Vector2(1.0, 0.0)), u.x)
	var b = lerp(hash12(i + Vector2(0.0, 1.0)), hash12(i + Vector2(1.0, 1.0)), u.x)
	
	return -1.0 + 2.0 * lerp(a, b, u.y)

func sea_octave(uv: Vector2, choppy: float) -> float:
	uv += Vector2.ONE * noise(uv)
	var wv := Vector2.ONE - Vector2(abs(sin(uv.x)), abs(sin(uv.y)))
	var swv := Vector2(abs(cos(uv.x)), abs(cos(uv.y)))
	
	# GDScript lerp component-by-component
	wv.x = lerp(wv.x, swv.x, wv.x)
	wv.y = lerp(wv.y, swv.y, wv.y)
	
	return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy)

# Calculates the exact world height of the water at a given 3D position
func get_water_height(global_pos: Vector3) -> float:
	var time := Time.get_ticks_msec() / 1000.0 # Syncs with shader TIME
	
	var freq := sea_freq
	var amp := sea_height
	var choppy := sea_choppy
	var uv := Vector2(global_pos.x, global_pos.z)
	uv.x *= 0.75
	
	var h := 0.0
	
	for i in range(3): # ITER_GEOMETRY
		var d := sea_octave((uv + Vector2.ONE * time * sea_speed) * freq, choppy)
		d += sea_octave((uv - Vector2.ONE * time * sea_speed) * freq, choppy)
		h += d * amp
		uv = OCTAVE_M * uv # Matrix multiplication
		freq *= 1.9
		amp *= 0.22
		choppy = lerp(choppy, 1.0, 0.2)
		
	return water_level_global_y + h
