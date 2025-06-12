# enemy_spawner.gd - FIXED: Complete implementation with multi-point spawn system
extends Node3D

signal wave_completed(wave_number: int)
signal all_waves_completed
signal enemy_spawned(enemy: Node3D)

# Wave configuration
@export var total_waves = 5
@export var base_enemies_per_wave = 3
@export var enemies_scale_per_wave = 2
@export var wave_delay = 3.0
@export var spawn_interval = 1.5

# ULTRA STRICT: Room-only spawn settings
@export var min_player_distance = 3.0
@export var spawn_height = 1.0
@export var max_spawn_attempts = 50
@export var spawn_distance_from_player = 6.0
@export var player_spawn_radius = 2.0

# Enemy scaling
@export var health_scale_per_wave = 1.3
@export var damage_scale_per_wave = 1.2
@export var speed_scale_per_wave = 1.1

# Boss settings
@export var boss_wave_interval = 5
@export var boss_scene: PackedScene

# Current state
var current_wave = 1
var enemies_in_current_wave = 0
var enemies_spawned_this_wave = 0
var total_enemies_for_wave = 0
var is_spawning = false
var wave_active = false

# Prevent double initialization
var has_been_initialized = false
var has_started_waves = false

# Room boundary enforcement
var terrain_generator: Node3D
var strict_room_bounds: Array[Rect2] = []
var current_room_index = 0
var map_size = Vector2(60, 60)

# Simple references
var player: Node3D
var enemy_scene: PackedScene
var spawn_timer: Timer
var wave_timer: Timer
var active_enemies: Array[Node3D] = []

# Room spawn tracking
var current_spawning_room: Rect2 = Rect2()
var current_spawning_room_index: int = 0
var spawn_only_in_newest_room: bool = true

# Control player proximity spawn
var disable_player_proximity_spawn: bool = false

# DEBUG: Visualize spawn attempts
var show_spawn_debug: bool = false
var debug_spawn_markers: Array = []

# Multi-point spawn system
var room_spawn_points: Dictionary = {}  # room_rect -> Array[Vector2]
var current_room_valid_points: Array[Vector2] = []
var spawn_point_padding: float = 2.5
var prefer_perimeter_spawning: bool = true

func set_spawn_mode(newest_room_only: bool = true, disable_proximity: bool = true):
	spawn_only_in_newest_room = newest_room_only
	disable_player_proximity_spawn = disable_proximity
	
	if newest_room_only:
		print("🎯 Enemy Spawner: Set to NEWEST ROOM ONLY mode")
	if disable_proximity:
		print("🚫 Enemy Spawner: Player proximity spawning DISABLED")

func _ready():
	add_to_group("spawner")
	_setup_timers()
	_load_enemy_scene()
	get_tree().create_timer(2.0).timeout.connect(_initialize)

func _setup_timers():
	spawn_timer = Timer.new()
	spawn_timer.name = "SpawnTimer"
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_spawn_enemy)
	add_child(spawn_timer)
	
	wave_timer = Timer.new()
	wave_timer.name = "WaveTimer"
	wave_timer.one_shot = true
	wave_timer.timeout.connect(_start_next_wave)
	add_child(wave_timer)

func _load_enemy_scene():
	if ResourceLoader.exists("res://Scenes/enemy.tscn"):
		enemy_scene = load("res://Scenes/enemy.tscn")
	else:
		print("❌ No enemy scene found!")
		
	if ResourceLoader.exists("res://Scenes/boss_enemy.tscn"):
		boss_scene = load("res://Scenes/boss_enemy.tscn")
	else:
		print("⚠️ No boss scene found!")

func _initialize():
	if has_been_initialized:
		return
	
	has_been_initialized = true
	
	player = get_tree().get_first_node_in_group("player")
	terrain_generator = get_tree().get_first_node_in_group("terrain")
	
	if not player or not terrain_generator:
		print("❌ Missing player or terrain, retrying initialization...")
		has_been_initialized = false
		get_tree().create_timer(2.0).timeout.connect(_initialize)
		return
	
	_get_strict_room_boundaries()

func _get_strict_room_boundaries():
	if not terrain_generator or not terrain_generator.has_method("get_rooms"):
		print("❌ Cannot get room boundaries!")
		return
	
	var rooms = terrain_generator.get_rooms()
	strict_room_bounds.clear()
	
	if "map_size" in terrain_generator:
		map_size = terrain_generator.map_size
	
	for room in rooms:
		strict_room_bounds.append(room)

func start_wave_system():
	if has_started_waves:
		print("Enemy Spawner: ✅ Waves already started!")
		return
	
	if not has_been_initialized:
		print("Enemy Spawner: ⚠️ Not initialized yet, cannot start waves")
		return
	
	has_started_waves = true
	print("Enemy Spawner: 🚀 Starting wave system!")
	current_wave = 1
	_start_wave(current_wave)

func set_room_boundaries(room_data: Dictionary):
	if room_data.has("rect"):
		var room_rect = room_data.rect
		if room_rect not in strict_room_bounds:
			strict_room_bounds.append(room_rect)
		
		current_spawning_room = room_rect
		current_spawning_room_index = strict_room_bounds.size() - 1
		
		print("Enemy Spawner: 🎯 Set newest room as spawning area: ", room_rect)
		print("Enemy Spawner: 📍 Spawning room index: ", current_spawning_room_index)
	
	if not has_started_waves and strict_room_bounds.size() > 0 and has_been_initialized:
		print("Enemy Spawner: 🚀 Auto-starting waves with newest room...")
		start_wave_system()

func _start_wave(wave_number: int):
	if wave_active:
		return
	
	current_wave = wave_number
	wave_active = true
	is_spawning = true
	
	var is_boss_wave = wave_number > 1 and wave_number % boss_wave_interval == 0
	
	if is_boss_wave and boss_scene:
		print("🔥 Starting BOSS wave ", wave_number, "!")
		total_enemies_for_wave = 1
	else:
		total_enemies_for_wave = base_enemies_per_wave + (wave_number - 1) * enemies_scale_per_wave
	
	enemies_spawned_this_wave = 0
	enemies_in_current_wave = 0
	
	print("🌊 Wave " + str(wave_number) + " Started")
	
	spawn_timer.start()
	_spawn_enemy()

func _spawn_enemy():
	if not is_spawning or not wave_active or not player:
		return
	
	if enemies_spawned_this_wave >= total_enemies_for_wave:
		spawn_timer.stop()
		is_spawning = false
		print("Enemy Spawner: All enemies spawned")
		return
	
	var enemy: Node3D
	var is_boss_wave = current_wave > 1 and current_wave % boss_wave_interval == 0
	
	if is_boss_wave and boss_scene:
		enemy = boss_scene.instantiate()
		print("🔥 Spawning BOSS!")
	else:
		enemy = enemy_scene.instantiate()
	
	if not enemy:
		return
	
	# Main spawn logic with priority system
	var spawn_pos = Vector3.ZERO
	
	if spawn_only_in_newest_room:
		spawn_pos = _get_ultra_strict_spawn_position()
	else:
		spawn_pos = _get_player_proximity_spawn_position()
		if spawn_pos == Vector3.ZERO:
			spawn_pos = _get_ultra_strict_spawn_position()
	
	# Emergency fallback
	if spawn_pos == Vector3.ZERO:
		spawn_pos = _emergency_spawn_near_player()
	
	# Final validation
	if spawn_pos == Vector3.ZERO:
		print("🚨 CRITICAL: Cannot spawn enemy safely - skipping this spawn")
		enemy.queue_free()
		return
	
	if not _is_position_in_any_room(spawn_pos):
		print("Enemy Spawner: ❌ Spawn position failed final room check: ", spawn_pos)
		enemy.queue_free()
		return
	
	get_parent().add_child(enemy)
	enemy.global_position = spawn_pos
	
	_scale_enemy_for_wave(enemy)
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))
	
	active_enemies.append(enemy)
	enemies_spawned_this_wave += 1
	enemies_in_current_wave += 1

	enemy_spawned.emit(enemy)
	print("Enemy Spawner: ✅ Spawned enemy ", enemies_spawned_this_wave, "/", total_enemies_for_wave, " at ", spawn_pos)

func _get_ultra_strict_spawn_position() -> Vector3:
	"""FIXED: Complete implementation using multi-point spawn system"""
	if strict_room_bounds.is_empty():
		print("Enemy Spawner: ❌ No room boundaries available!")
		return Vector3.ZERO
	
	var target_room: Rect2
	if current_spawning_room != Rect2():
		target_room = current_spawning_room
	else:
		target_room = strict_room_bounds[strict_room_bounds.size() - 1]
	
	print("🎯 Finding spawn in room: ", target_room)
	
	# Get or generate spawn points for this room
	var spawn_points = room_spawn_points.get(target_room, [])
	if spawn_points.is_empty():
		spawn_points = _generate_and_cache_spawn_points(target_room)
	
	# Try predefined spawn points first
	if prefer_perimeter_spawning and spawn_points.size() > 0:
		var shuffled_points = spawn_points.duplicate()
		shuffled_points.shuffle()
		
		for point in shuffled_points:
			var world_pos = Vector3(
				(point.x - map_size.x / 2) * 2.0,
				spawn_height,
				(point.y - map_size.y / 2) * 2.0
			)
			
			var validation = _validate_spawn_area(world_pos)
			if validation["valid"]:
				_create_debug_spawn_marker(validation["final_position"], true, "PREDEFINED POINT")
				return validation["final_position"]
	
	# Fallback to random positioning
	return _get_fallback_random_position(target_room)

func _generate_and_cache_spawn_points(room_rect: Rect2) -> Array[Vector2]:
	"""FIXED: Generate and cache spawn points for a room"""
	var points = _generate_room_spawn_points(room_rect)
	var valid_points = _validate_spawn_points(points, room_rect)
	
	room_spawn_points[room_rect] = valid_points
	print("🗺️ Generated ", valid_points.size(), " valid spawn points for room: ", room_rect)
	
	return valid_points

func _generate_room_spawn_points(room_rect: Rect2) -> Array[Vector2]:
	"""Create spawn points around room perimeter and corners"""
	var points: Array[Vector2] = []
	
	var min_x = room_rect.position.x + spawn_point_padding
	var max_x = room_rect.position.x + room_rect.size.x - spawn_point_padding
	var min_y = room_rect.position.y + spawn_point_padding
	var max_y = room_rect.position.y + room_rect.size.y - spawn_point_padding
	
	var mid_x = room_rect.position.x + room_rect.size.x / 2
	var mid_y = room_rect.position.y + room_rect.size.y / 2
	
	# Corner positions (4 corners)
	points.append(Vector2(min_x, min_y))
	points.append(Vector2(max_x, min_y))
	points.append(Vector2(min_x, max_y))
	points.append(Vector2(max_x, max_y))
	
	# Mid-wall positions
	if room_rect.size.x >= 8:
		points.append(Vector2(mid_x, min_y))
		points.append(Vector2(mid_x, max_y))
	
	if room_rect.size.y >= 8:
		points.append(Vector2(min_x, mid_y))
		points.append(Vector2(max_x, mid_y))
	
	# Additional points for larger rooms
	if room_rect.size.x >= 12 and room_rect.size.y >= 12:
		var quarter_x1 = min_x + (max_x - min_x) * 0.25
		var quarter_x2 = min_x + (max_x - min_x) * 0.75
		var quarter_y1 = min_y + (max_y - min_y) * 0.25
		var quarter_y2 = min_y + (max_y - min_y) * 0.75
		
		points.append(Vector2(quarter_x1, quarter_y1))
		points.append(Vector2(quarter_x2, quarter_y1))
		points.append(Vector2(quarter_x1, quarter_y2))
		points.append(Vector2(quarter_x2, quarter_y2))
	
	return points

func _validate_spawn_points(points: Array[Vector2], room_rect: Rect2) -> Array[Vector2]:
	"""Filter spawn points to only include safe/valid ones"""
	var valid_points: Array[Vector2] = []
	
	for point in points:
		if _is_spawn_point_safe(point, room_rect):
			valid_points.append(point)
	
	return valid_points

func _is_spawn_point_safe(grid_point: Vector2, room_rect: Rect2) -> bool:
	"""Check if a grid position is safe for spawning"""
	if not room_rect.has_point(grid_point):
		return false
	
	var world_pos = Vector3(
		(grid_point.x - map_size.x / 2) * 2.0,
		spawn_height,
		(grid_point.y - map_size.y / 2) * 2.0
	)
	
	if player and world_pos.distance_to(player.global_position) < min_player_distance:
		return false
	
	if terrain_generator and terrain_generator.has_method("_is_valid_pos"):
		var grid_x = int(grid_point.x)
		var grid_y = int(grid_point.y)
		
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var check_x = grid_x + dx
				var check_y = grid_y + dy
				if not terrain_generator._is_valid_pos(check_x, check_y):
					return false
	
	return true

func _get_fallback_random_position(room_rect: Rect2) -> Vector3:
	"""Fallback to random positioning system"""
	print("🎲 Using fallback random positioning")
	
	var attempts = 0
	while attempts < max_spawn_attempts:
		attempts += 1
		
		var room_x = randf_range(room_rect.position.x + spawn_point_padding, 
								room_rect.position.x + room_rect.size.x - spawn_point_padding)
		var room_y = randf_range(room_rect.position.y + spawn_point_padding, 
								room_rect.position.y + room_rect.size.y - spawn_point_padding)
		
		var test_pos = Vector3(
			(room_x - map_size.x / 2) * 2.0,
			spawn_height,
			(room_y - map_size.y / 2) * 2.0
		)
		
		var validation = _validate_spawn_area(test_pos)
		if validation["valid"]:
			_create_debug_spawn_marker(validation["final_position"], false, "RANDOM FALLBACK")
			return validation["final_position"]
	
	return Vector3.ZERO

func _get_player_proximity_spawn_position() -> Vector3:
	"""Spawn in 8-point compass pattern around player"""
	if not player or strict_room_bounds.is_empty():
		return Vector3.ZERO
	
	var directions = [
		Vector3(0, 0, -1), Vector3(1, 0, -1).normalized(), Vector3(1, 0, 0),
		Vector3(1, 0, 1).normalized(), Vector3(0, 0, 1), Vector3(-1, 0, 1).normalized(),
		Vector3(-1, 0, 0), Vector3(-1, 0, -1).normalized()
	]
	
	var player_pos = player.global_position
	var min_dist = max(player_spawn_radius, 4.0)
	var max_dist = max(spawn_distance_from_player, min_dist)
	
	for dir in directions:
		for dist in [min_dist, max_dist]:
			var candidate = player_pos + dir * dist
			candidate.y = spawn_height
			if _is_valid_player_spawn(candidate):
				return candidate
	
	return Vector3.ZERO

func _is_valid_player_spawn(world_pos: Vector3) -> bool:
	if not _is_position_in_any_room(world_pos):
		return false
	if player and world_pos.distance_to(player.global_position) < player_spawn_radius:
		return false
	
	for enemy in active_enemies:
		if is_instance_valid(enemy) and world_pos.distance_to(enemy.global_position) < 2.0:
			return false
	
	if terrain_generator and terrain_generator.has_method("_is_valid_pos"):
		var grid_x = int((world_pos.x / 2.0) + (map_size.x / 2))
		var grid_y = int((world_pos.z / 2.0) + (map_size.y / 2))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var check_x = grid_x + dx
				var check_y = grid_y + dy
				if not terrain_generator._is_valid_pos(check_x, check_y):
					return false
	return true

func _is_position_in_any_room(world_pos: Vector3) -> bool:
	var grid_x = (world_pos.x / 2.0) + (map_size.x / 2)
	var grid_y = (world_pos.z / 2.0) + (map_size.y / 2)
	
	for room in strict_room_bounds:
		if room.has_point(Vector2(grid_x, grid_y)):
			return true
	
	return false

func set_newest_spawning_room(room_rect: Rect2):
	"""Called when a new room is created"""
	current_spawning_room = room_rect
	
	if room_rect not in strict_room_bounds:
		strict_room_bounds.append(room_rect)
	
	for i in range(strict_room_bounds.size()):
		if strict_room_bounds[i] == room_rect:
			current_spawning_room_index = i
			break
	
	# Pre-generate spawn points for this room
	_generate_and_cache_spawn_points(room_rect)
	
	set_spawn_mode(true, true)
	
	print("🆕 Enemy Spawner: Updated to spawn in newest room with ", 
		  room_spawn_points.get(room_rect, []).size(), " spawn points: ", room_rect)

func _scale_enemy_for_wave(enemy: Node3D):
	if not enemy.has_method("set_stats"):
		return
	
	var health_mult = pow(health_scale_per_wave, current_wave - 1)
	var damage_mult = pow(damage_scale_per_wave, current_wave - 1)
	var speed_mult = pow(speed_scale_per_wave, current_wave - 1)
	
	var new_health = int(30 * health_mult)
	var new_damage = int(5 * damage_mult)
	var new_speed = 2.0 * speed_mult
	
	enemy.set_stats(new_health, new_damage, new_speed)

func _on_enemy_died(enemy: Node3D):
	enemies_in_current_wave -= 1
	active_enemies.erase(enemy)
	
	if enemies_in_current_wave <= 0 and not is_spawning:
		_complete_wave()

func _complete_wave():
	wave_active = false
	print("🌊 Wave " + str(current_wave) + " Complete")
	
	wave_completed.emit(current_wave)
	
	if current_wave >= total_waves:
		print("🏆 All Waves Complete!")
		all_waves_completed.emit()
		return
	
	wave_timer.wait_time = wave_delay
	wave_timer.start()

func _start_next_wave():
	current_wave += 1
	_get_strict_room_boundaries()
	_start_wave(current_wave)

# Include validation functions from original
func _is_ground_safe_at_position(world_pos: Vector3) -> Dictionary:
	var space_state = get_parent().get_world_3d().direct_space_state
	var ray_from = world_pos + Vector3(0, 5, 0)
	var ray_to = world_pos + Vector3(0, -2, 0)
	
	var ray_query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	ray_query.collision_mask = 1
	ray_query.exclude = []
	
	var result = space_state.intersect_ray(ray_query)
	
	if result.is_empty():
		return {"safe": false, "reason": "no_ground", "ground_y": 0.0}
	
	var hit_point = result["position"]
	var hit_normal = result["normal"]
	var hit_object = result["collider"]
	
	var surface_angle = rad_to_deg(hit_normal.angle_to(Vector3.UP))
	if surface_angle > 45:
		return {"safe": false, "reason": "too_steep", "ground_y": hit_point.y, "angle": surface_angle}
	
	if hit_object.name.contains("Wall") or hit_object.name.contains("Boundary"):
		return {"safe": false, "reason": "hit_wall", "ground_y": hit_point.y}
	
	return {"safe": true, "reason": "valid_ground", "ground_y": hit_point.y, "surface_angle": surface_angle}

func _is_space_clear_for_enemy(world_pos: Vector3, check_radius: float = 0.8) -> Dictionary:
	var space_state = get_parent().get_world_3d().direct_space_state
	
	var shape = CapsuleShape3D.new()
	shape.radius = check_radius * 0.5
	shape.height = 1.5
	
	var shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform = Transform3D(Basis(), world_pos + Vector3(0, 0.75, 0))
	shape_query.collision_mask = 1 | 2
	shape_query.exclude = []
	
	var collisions = space_state.intersect_shape(shape_query)
	
	if collisions.is_empty():
		return {"clear": true, "reason": "no_collisions"}
	
	var collision_types = []
	for collision in collisions:
		var collider = collision["collider"]
		if collider.name.contains("Wall") or collider.name.contains("Boundary"):
			collision_types.append("wall")
		elif collider.is_in_group("enemies"):
			collision_types.append("enemy")
		elif collider.is_in_group("player"):
			collision_types.append("player")
		else:
			collision_types.append("unknown: " + collider.name)
	
	return {"clear": false, "reason": "collisions", "collision_types": collision_types}

func _validate_spawn_area(world_pos: Vector3) -> Dictionary:
	var validation_result = {
		"valid": false,
		"ground_check": {},
		"collision_check": {},
		"area_check": {},
		"final_position": world_pos
	}
	
	var ground_check = _is_ground_safe_at_position(world_pos)
	validation_result["ground_check"] = ground_check
	
	if not ground_check["safe"]:
		validation_result["reason"] = "Ground unsafe: " + ground_check["reason"]
		return validation_result
	
	var adjusted_pos = Vector3(world_pos.x, ground_check["ground_y"] + 0.1, world_pos.z)
	validation_result["final_position"] = adjusted_pos
	
	var collision_check = _is_space_clear_for_enemy(adjusted_pos)
	validation_result["collision_check"] = collision_check
	
	if not collision_check["clear"]:
		validation_result["reason"] = "Collision detected: " + str(collision_check["collision_types"])
		return validation_result
	
	var check_points = [
		adjusted_pos,
		adjusted_pos + Vector3(0.5, 0, 0),
		adjusted_pos + Vector3(-0.5, 0, 0),
		adjusted_pos + Vector3(0, 0, 0.5),
		adjusted_pos + Vector3(0, 0, -0.5)
	]
	
	var area_safe = true
	var unsafe_points = []
	
	for point in check_points:
		var point_collision = _is_space_clear_for_enemy(point, 0.4)
		if not point_collision["clear"]:
			area_safe = false
			unsafe_points.append(point_collision)
	
	validation_result["area_check"] = {
		"safe": area_safe,
		"unsafe_points": unsafe_points.size(),
		"total_points": check_points.size()
	}
	
	if not area_safe:
		validation_result["reason"] = "Area not safe: " + str(unsafe_points.size()) + "/" + str(check_points.size()) + " points blocked"
		return validation_result
	
	validation_result["valid"] = true
	validation_result["reason"] = "All safety checks passed"
	return validation_result

func _create_debug_spawn_marker(marker_position: Vector3, is_valid: bool, reason: String = ""):
	if not show_spawn_debug:
		return
	
	var marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	marker.mesh = sphere
	
	var material = StandardMaterial3D.new()
	if is_valid:
		material.albedo_color = Color.GREEN
		material.emission = Color.GREEN * 0.8
	else:
		if reason.contains("Ground"):
			material.albedo_color = Color.BLUE
		elif reason.contains("Collision"):
			material.albedo_color = Color.RED
		elif reason.contains("Area"):
			material.albedo_color = Color.YELLOW
		else:
			material.albedo_color = Color.MAGENTA
		
		material.emission = material.albedo_color * 0.5
	
	material.emission_enabled = true
	marker.material_override = material
	
	marker.position = marker_position + Vector3(0, 1, 0)
	get_parent().add_child(marker)
	debug_spawn_markers.append(marker)
	
	if reason != "":
		var text_label = Label3D.new()
		text_label.text = reason
		text_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text_label.font_size = 24
		text_label.position = Vector3(0, 0.5, 0)
		marker.add_child(text_label)
	
	get_tree().create_timer(15.0).timeout.connect(
		func(): 
			if is_instance_valid(marker):
				marker.queue_free()
			debug_spawn_markers.erase(marker)
	)

func _emergency_spawn_near_player() -> Vector3:
	if not player:
		return Vector3.ZERO
	
	print("🚨 EMERGENCY SPAWN: Using player proximity as last resort")
	
	for distance in [4.0, 6.0, 8.0]:
		for angle_deg in range(0, 360, 45):
			var angle_rad = deg_to_rad(angle_deg)
			var test_pos = player.global_position + Vector3(
				cos(angle_rad) * distance,
				2.0,
				sin(angle_rad) * distance
			)
			
			var validation = _validate_spawn_area(test_pos)
			if validation["valid"]:
				print("🚨 Emergency spawn successful at distance ", distance, ", angle ", angle_deg)
				return validation["final_position"]
	
	print("🚨 CRITICAL: Even emergency spawn failed!")
	return Vector3.ZERO

# Public API for UI and other systems
func get_wave_info() -> Dictionary:
	return {
		"current_wave": current_wave,
		"max_waves": total_waves,
		"current_enemies": enemies_in_current_wave,
		"enemies_spawned": enemies_spawned_this_wave,
		"total_enemies_for_wave": total_enemies_for_wave,
		"wave_active": wave_active,
		"is_spawning": is_spawning,
		"room_constrained": true,
		"strict_room_count": strict_room_bounds.size(),
		"spawn_area": strict_room_bounds,
		"has_been_initialized": has_been_initialized,
		"has_started_waves": has_started_waves
	}

func force_next_wave():
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	active_enemies.clear()
	enemies_in_current_wave = 0
	_complete_wave()

func reset_spawner():
	spawn_timer.stop()
	wave_timer.stop()
	
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	active_enemies.clear()
	current_wave = 1
	enemies_in_current_wave = 0
	enemies_spawned_this_wave = 0
	is_spawning = false
	wave_active = false
	has_started_waves = false
