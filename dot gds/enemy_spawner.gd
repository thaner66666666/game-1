# enemy_spawner.gd - FIXED: Prevents double wave starting
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
@export var max_spawn_attempts = 50  # More attempts to find valid spots
@export var spawn_distance_from_player = 6.0 # Distance for 8-point pattern
@export var player_spawn_radius = 2.0 # Minimum distance from player for 8-point pattern

# Enemy scaling
@export var health_scale_per_wave = 1.3
@export var damage_scale_per_wave = 1.2
@export var speed_scale_per_wave = 1.1

# Boss settings
@export var boss_wave_interval = 5  # Spawn boss every X waves
@export var boss_scene: PackedScene

# Current state
var current_wave = 1
var enemies_in_current_wave = 0
var enemies_spawned_this_wave = 0
var total_enemies_for_wave = 0
var is_spawning = false
var wave_active = false

# FIXED: Prevent double initialization
var has_been_initialized = false
var has_started_waves = false

# ULTRA STRICT: Room boundary enforcement
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

# --- ADDED: Room spawn tracking ---
var current_spawning_room: Rect2 = Rect2()
var current_spawning_room_index: int = 0
var spawn_only_in_newest_room: bool = true  # Feature flag

# --- NEW: Control player proximity spawn ---
var disable_player_proximity_spawn: bool = false

# --- DEBUG: Visualize spawn attempts ---
var show_spawn_debug: bool = true
var debug_spawn_markers: Array = []

func set_spawn_mode(newest_room_only: bool = true, disable_proximity: bool = true):
	"""Control how enemies spawn - room-based vs player proximity"""
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
		
	# Load boss scene
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
	"""Public method to start the wave system"""
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

# LEGACY COMPATIBILITY - but now uses strict room checking
func set_room_boundaries(room_data: Dictionary):
	"""Set room boundaries and mark this as the current spawning room"""
	if room_data.has("rect"):
		var room_rect = room_data.rect
		if room_rect not in strict_room_bounds:
			strict_room_bounds.append(room_rect)
		
		# Set this as the current spawning room (newest room)
		current_spawning_room = room_rect
		current_spawning_room_index = strict_room_bounds.size() - 1
		
		print("Enemy Spawner: 🎯 Set newest room as spawning area: ", room_rect)
		print("Enemy Spawner: 📍 Spawning room index: ", current_spawning_room_index)
	
	# Auto-start waves if conditions are met
	if not has_started_waves and strict_room_bounds.size() > 0 and has_been_initialized:
		print("Enemy Spawner: 🚀 Auto-starting waves with newest room...")
		start_wave_system()

func _start_wave(wave_number: int):
	if wave_active:
		return
	
	current_wave = wave_number
	wave_active = true
	is_spawning = true
	
	# Check if this is a boss wave
	var is_boss_wave = wave_number > 1 and wave_number % boss_wave_interval == 0
	
	if is_boss_wave and boss_scene:
		print("🔥 Starting BOSS wave ", wave_number, "!")
		total_enemies_for_wave = 1  # Just the boss
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
	
	# Create enemy or boss
	var enemy: Node3D
	var is_boss_wave = current_wave > 1 and current_wave % boss_wave_interval == 0
	
	if is_boss_wave and boss_scene:
		enemy = boss_scene.instantiate()
		print("🔥 Spawning BOSS!")
	else:
		enemy = enemy_scene.instantiate()
	
	if not enemy:
		return
	
	# --- UPDATED: Main spawn logic with emergency fallback ---
	var spawn_pos = Vector3.ZERO
	
	# Try primary spawn method
	if spawn_only_in_newest_room:
		spawn_pos = _get_ultra_strict_spawn_position()
	else:
		spawn_pos = _get_player_proximity_spawn_position()
		if spawn_pos == Vector3.ZERO:
			spawn_pos = _get_ultra_strict_spawn_position()
	
	# Emergency fallback if everything fails
	if spawn_pos == Vector3.ZERO:
		spawn_pos = _emergency_spawn_near_player()
	
	# CRITICAL: If still no position, skip this enemy
	if spawn_pos == Vector3.ZERO:
		print("🚨 CRITICAL: Cannot spawn enemy safely - skipping this spawn")
		enemy.queue_free()
		return
	
	# Validate spawn position one more time
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

func _get_player_proximity_spawn_position() -> Vector3:
	"""Spawn in 8-point compass pattern around player, 4-8 units away, within room bounds"""
	if not player or strict_room_bounds.is_empty():
		return Vector3.ZERO
	
	var directions = [
		Vector3(0, 0, -1),   # N
		Vector3(1, 0, -1).normalized(), # NE
		Vector3(1, 0, 0),    # E
		Vector3(1, 0, 1).normalized(),  # SE
		Vector3(0, 0, 1),    # S
		Vector3(-1, 0, 1).normalized(), # SW
		Vector3(-1, 0, 0),   # W
		Vector3(-1, 0, -1).normalized() # NW
	]
	
	var player_pos = player.global_position
	var min_dist = max(player_spawn_radius, 4.0)
	var max_dist = max(spawn_distance_from_player, min_dist)
	
	for dir in directions:
		# Try at min and max distance for each direction
		for dist in [min_dist, max_dist]:
			var candidate = player_pos + dir * dist
			candidate.y = spawn_height
			if _is_valid_player_spawn(candidate):
				return candidate
	# No valid position found in 8-point pattern
	return Vector3.ZERO

func _is_valid_player_spawn(world_pos: Vector3) -> bool:
	# Must be within any room
	if not _is_position_in_any_room(world_pos):
		return false
	# Not too close to player
	if player and world_pos.distance_to(player.global_position) < player_spawn_radius:
		return false
	# Not too close to other enemies
	for enemy in active_enemies:
		if is_instance_valid(enemy) and world_pos.distance_to(enemy.global_position) < 2.0:
			return false
	# Check terrain grid if available (ensure not in wall, check 3x3 area)
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

# (Keep the old fallback for room-based spawning)
func _get_ultra_strict_spawn_position() -> Vector3:
	"""ULTRA SAFE: Comprehensive spawn validation with ground and collision detection"""
	if strict_room_bounds.is_empty():
		print("Enemy Spawner: ❌ No room boundaries available!")
		return Vector3.ZERO
	
	var target_room: Rect2
	if current_spawning_room != Rect2():
		target_room = current_spawning_room
	else:
		target_room = strict_room_bounds[strict_room_bounds.size() - 1]
	
	print("🎯 Finding ULTRA SAFE spawn in room: ", target_room)
	
	var attempts = 0
	var max_attempts = max_spawn_attempts * 3  # More attempts for safety
	var validation_stats = {
		"total_attempts": 0,
		"ground_failures": 0,
		"collision_failures": 0,
		"area_failures": 0,
		"success": 0
	}
	
	while attempts < max_attempts:
		attempts += 1
		validation_stats["total_attempts"] += 1
		
		# Generate position with more padding from walls
		var room_x = randf_range(target_room.position.x + 2.5, target_room.position.x + target_room.size.x - 2.5)
		var room_y = randf_range(target_room.position.y + 2.5, target_room.position.y + target_room.size.y - 2.5)
		
		var test_pos = Vector3(
			(room_x - map_size.x / 2) * 2.0,
			spawn_height,
			(room_y - map_size.y / 2) * 2.0
		)
		
		# Comprehensive validation
		var validation = _validate_spawn_area(test_pos)
		
		# Track failure reasons
		if not validation["valid"]:
			if validation["reason"].contains("Ground"):
				validation_stats["ground_failures"] += 1
			elif validation["reason"].contains("Collision"):
				validation_stats["collision_failures"] += 1
			elif validation["reason"].contains("Area"):
				validation_stats["area_failures"] += 1
			
			# Create debug marker for failed attempt
			_create_debug_spawn_marker(test_pos, false, validation["reason"])
			continue
		
		# SUCCESS!
		validation_stats["success"] += 1
		var final_pos = validation["final_position"]
		
		print("Enemy Spawner: ✅ ULTRA SAFE spawn found at ", final_pos, " (attempt ", attempts, ")")
		print("  Ground Y: ", validation["ground_check"]["ground_y"])
		print("  Surface angle: ", validation["ground_check"].get("surface_angle", "N/A"), "°")
		
		# Create debug marker for successful spawn
		_create_debug_spawn_marker(final_pos, true, "SAFE SPAWN")
		
		return final_pos
	
	# Print detailed failure statistics
	print("Enemy Spawner: ❌ ULTRA SAFE spawn failed after ", attempts, " attempts")
	print("  Failure breakdown:")
	print("    Ground issues: ", validation_stats["ground_failures"])
	print("    Collision issues: ", validation_stats["collision_failures"])
	print("    Area issues: ", validation_stats["area_failures"])
	print("    Success rate: ", float(validation_stats["success"]) / float(validation_stats["total_attempts"]) * 100, "%")
	
	return Vector3.ZERO

func _is_ultra_strict_spawn_valid(world_pos: Vector3, room: Rect2) -> bool:
	"""ULTRA STRICT validation of spawn position"""
	
	# Convert world position back to grid position for double-checking
	var grid_x = (world_pos.x / 2.0) + (map_size.x / 2)
	var grid_y = (world_pos.z / 2.0) + (map_size.y / 2)
	
	# STRICT: Must be within room bounds
	if not room.has_point(Vector2(grid_x, grid_y)):
		return false
	
	# Check distance from player
	if player and world_pos.distance_to(player.global_position) < min_player_distance:
		return false
	
	# Check distance from other enemies
	for enemy in active_enemies:
		if is_instance_valid(enemy) and world_pos.distance_to(enemy.global_position) < 2.0:
			return false
	
	# ADDITIONAL: Make sure it's not too close to walls by checking terrain grid
	if terrain_generator and terrain_generator.has_method("_is_valid_pos"):
		# Check surrounding positions are safe
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var check_x = int(grid_x + dx)
				var check_y = int(grid_y + dy)
				if not terrain_generator._is_valid_pos(check_x, check_y):
					return false
				# Could add terrain grid check here if the terrain has public access
	
	return true

func _is_position_in_any_room(world_pos: Vector3) -> bool:
	"""Final check: is position in ANY room?"""
	var grid_x = (world_pos.x / 2.0) + (map_size.x / 2)
	var grid_y = (world_pos.z / 2.0) + (map_size.y / 2)
	
	for room in strict_room_bounds:
		if room.has_point(Vector2(grid_x, grid_y)):
			return true
	
	return false

func _create_enemy() -> Node3D:
	if enemy_scene:
		return enemy_scene.instantiate()
	
	# Fallback
	var enemy_script = load("res://dot gds/enemy.gd")
	if enemy_script:
		var enemy = CharacterBody3D.new()
		enemy.name = "Enemy"
		enemy.script = enemy_script
		return enemy
	
	print("❌ Enemy Spawner: Could not create enemy - missing scene and script!")
	return null

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
	
	# Refresh room boundaries for new rooms
	_get_strict_room_boundaries()
	
	_start_wave(current_wave)

# Public API - keep same interface for UI
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
	has_started_waves = false  # FIXED: Reset this too

func set_newest_spawning_room(room_rect: Rect2):
	"""Called when a new room is created - makes it the active spawning room"""
	current_spawning_room = room_rect
	
	# Add to bounds if not already there
	if room_rect not in strict_room_bounds:
		strict_room_bounds.append(room_rect)
	
	# Update index to point to newest room
	for i in range(strict_room_bounds.size()):
		if strict_room_bounds[i] == room_rect:
			current_spawning_room_index = i
			break
	
	# Automatically enable newest room only mode
	set_spawn_mode(true, true)
	
	print("🆕 Enemy Spawner: Updated to spawn in newest room: ", room_rect)
	print("📍 Room index: ", current_spawning_room_index, " of ", strict_room_bounds.size())

func _is_ground_safe_at_position(world_pos: Vector3) -> Dictionary:
	"""Check if there's solid ground at this position using raycast"""
	var space_state = get_parent().get_world_3d().direct_space_state
	
	# Cast ray from above to find ground
	var ray_from = world_pos + Vector3(0, 5, 0)  # Start 5 units above
	var ray_to = world_pos + Vector3(0, -2, 0)   # Go 2 units below spawn point
	
	var ray_query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	ray_query.collision_mask = 1  # Ground/walls layer
	ray_query.exclude = []
	
	var result = space_state.intersect_ray(ray_query)
	
	if result.is_empty():
		return {"safe": false, "reason": "no_ground", "ground_y": 0.0}
	
	var hit_point = result["position"]
	var hit_normal = result["normal"]
	var hit_object = result["collider"]
	
	# Check if the surface is flat enough (not a wall)
	var surface_angle = rad_to_deg(hit_normal.angle_to(Vector3.UP))
	if surface_angle > 45:  # Too steep
		return {"safe": false, "reason": "too_steep", "ground_y": hit_point.y, "angle": surface_angle}
	
	# Check if it's actually ground (not a wall or ceiling)
	if hit_object.name.contains("Wall") or hit_object.name.contains("Boundary"):
		return {"safe": false, "reason": "hit_wall", "ground_y": hit_point.y}
	
	return {"safe": true, "reason": "valid_ground", "ground_y": hit_point.y, "surface_angle": surface_angle}

func _is_space_clear_for_enemy(world_pos: Vector3, check_radius: float = 0.8) -> Dictionary:
	"""Check if space is clear for enemy spawn using shape casting"""
	var space_state = get_parent().get_world_3d().direct_space_state
	
	# Create a capsule shape to represent the enemy
	var shape = CapsuleShape3D.new()
	shape.radius = check_radius * 0.5  # Enemy radius
	shape.height = 1.5  # Enemy height
	
	var shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform = Transform3D(Basis(), world_pos + Vector3(0, 0.75, 0))  # Center the capsule
	shape_query.collision_mask = 1 | 2  # Check walls and other enemies
	shape_query.exclude = []
	
	var collisions = space_state.intersect_shape(shape_query)
	
	if collisions.is_empty():
		return {"clear": true, "reason": "no_collisions"}
	
	# Analyze what we're colliding with
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
	"""Comprehensive spawn validation with multiple check points"""
	var validation_result = {
		"valid": false,
		"ground_check": {},
		"collision_check": {},
		"area_check": {},
		"final_position": world_pos
	}
	
	# 1. Check ground safety
	var ground_check = _is_ground_safe_at_position(world_pos)
	validation_result["ground_check"] = ground_check
	
	if not ground_check["safe"]:
		validation_result["reason"] = "Ground unsafe: " + ground_check["reason"]
		return validation_result
	
	# 2. Adjust position to ground level
	var adjusted_pos = Vector3(world_pos.x, ground_check["ground_y"] + 0.1, world_pos.z)
	validation_result["final_position"] = adjusted_pos
	
	# 3. Check for collisions at adjusted position
	var collision_check = _is_space_clear_for_enemy(adjusted_pos)
	validation_result["collision_check"] = collision_check
	
	if not collision_check["clear"]:
		validation_result["reason"] = "Collision detected: " + str(collision_check["collision_types"])
		return validation_result
	
	# 4. Check surrounding area (5 points around the center)
	var check_points = [
		adjusted_pos,  # Center
		adjusted_pos + Vector3(0.5, 0, 0),    # Right
		adjusted_pos + Vector3(-0.5, 0, 0),   # Left
		adjusted_pos + Vector3(0, 0, 0.5),    # Forward
		adjusted_pos + Vector3(0, 0, -0.5)    # Back
	]
	
	var area_safe = true
	var unsafe_points = []
	
	for point in check_points:
		var point_collision = _is_space_clear_for_enemy(point, 0.4)  # Smaller radius for area check
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
	
	# All checks passed!
	validation_result["valid"] = true
	validation_result["reason"] = "All safety checks passed"
	return validation_result

func _create_debug_spawn_marker(position: Vector3, is_valid: bool, reason: String = ""):
	"""Create a visual marker to show spawn attempts with reasons"""
	if not show_spawn_debug:
		return
	
	var marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	marker.mesh = sphere
	
	# Color code based on result
	var material = StandardMaterial3D.new()
	if is_valid:
		material.albedo_color = Color.GREEN
		material.emission = Color.GREEN * 0.8
	else:
		# Different colors for different failure types
		if reason.contains("Ground"):
			material.albedo_color = Color.BLUE  # Ground issues = blue
		elif reason.contains("Collision"):
			material.albedo_color = Color.RED   # Collision issues = red
		elif reason.contains("Area"):
			material.albedo_color = Color.YELLOW # Area issues = yellow
		else:
			material.albedo_color = Color.MAGENTA # Unknown = magenta
		
		material.emission = material.albedo_color * 0.5
	
	material.emission_enabled = true
	marker.material_override = material
	
	marker.position = position + Vector3(0, 1, 0)  # Float above
	get_parent().add_child(marker)
	debug_spawn_markers.append(marker)
	
	# Add floating text with reason
	if reason != "":
		var text_label = Label3D.new()
		text_label.text = reason
		text_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text_label.font_size = 24
		text_label.position = Vector3(0, 0.5, 0)
		marker.add_child(text_label)
	
	# Auto-remove after 15 seconds
	get_tree().create_timer(15.0).timeout.connect(
		func(): 
			if is_instance_valid(marker):
				marker.queue_free()
			debug_spawn_markers.erase(marker)
	)

func _emergency_spawn_near_player() -> Vector3:
	"""Emergency fallback: spawn enemy safely near player as last resort"""
	if not player:
		return Vector3.ZERO
	
	print("🚨 EMERGENCY SPAWN: Using player proximity as last resort")
	
	# Try positions in a circle around player
	for distance in [4.0, 6.0, 8.0]:  # Try increasing distances
		for angle_deg in range(0, 360, 45):  # Every 45 degrees
			var angle_rad = deg_to_rad(angle_deg)
			var test_pos = player.global_position + Vector3(
				cos(angle_rad) * distance,
				2.0,  # Start higher
				sin(angle_rad) * distance
			)
			
			var validation = _validate_spawn_area(test_pos)
			if validation["valid"]:
				print("🚨 Emergency spawn successful at distance ", distance, ", angle ", angle_deg)
				return validation["final_position"]
	
	print("🚨 CRITICAL: Even emergency spawn failed!")
	return Vector3.ZERO
