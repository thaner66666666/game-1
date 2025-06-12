# EnemySpawner.gd - FIXED VERSION
# Purpose: Spawns waves of enemies close to the player for immediate action
# Author: Thane (Fixed by Claude)
# Last Modified: June 12, 2025

extends Node3D

# === EXPORTED VARIABLES (Now with better defaults) ===
@export var enemy_scene: PackedScene
@export var spawn_radius_min: float = 2.0  # NEW: Minimum spawn distance (creates breathing room)
@export var spawn_radius_max: float = 5.0  # FIXED: Closer spawn distance 
@export var max_distance_from_player: float = 8.0  # NEW: Don't spawn too far away
@export var spawn_attempts: int = 50  # Increased attempts for better positioning
@export var enemies_per_wave: int = 5
@export var wave_delay: float = 3.0  # Faster waves for more action
@export var use_player_position: bool = true  # NEW: Prioritize player position over room center

# === PRIVATE VARIABLES ===
var player: Node3D = null
var latest_room_position: Vector3 = Vector3.ZERO
var current_wave: int = 1
var wave_timer: Timer = null
var enemies_alive: Array = []
var max_waves: int = 5

# NEW: Spawn positioning system
var spawn_center_cache: Vector3 = Vector3.ZERO
var last_spawn_update_time: float = 0.0
const SPAWN_CENTER_UPDATE_INTERVAL = 1.0  # Update spawn center every second

signal wave_completed(wave_number: int)  # NEW: Signal for room generation
signal all_waves_complete()

func _ready() -> void:
	print("🎯 IMPROVED Enemy Spawner: Starting up...")
	
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("Player not found in group 'player'")
		return

	# Load fallback enemy scene
	if enemy_scene == null:
		var fallback_path = "res://Scenes/enemy.tscn"
		if ResourceLoader.exists(fallback_path):
			enemy_scene = load(fallback_path)
			print("[EnemySpawner] Loaded fallback enemy scene.")
		else:
			push_error("[EnemySpawner] No enemy scene set and fallback not found!")
			return

	# Set up wave timer
	wave_timer = Timer.new()
	wave_timer.wait_time = wave_delay
	wave_timer.one_shot = true
	wave_timer.timeout.connect(_on_wave_timer_timeout)
	add_child(wave_timer)
	
	print("✅ Improved Enemy Spawner ready!")

# === IMPROVED WAVE SYSTEM ===
func start_wave() -> void:
	if enemy_scene == null:
		push_error("Enemy scene not set!")
		return

	print("🎯 [Wave %d] Starting with smart spawn positioning..." % current_wave)
	enemies_alive.clear()

	# NEW: Smart spawn center calculation
	var spawn_center = _calculate_smart_spawn_center()
	print("🎯 Using spawn center: ", spawn_center)

	var enemies_spawned = 0
	var spawn_attempts_used = 0
	
	# NEW: Spawn with better positioning logic
	while enemies_spawned < enemies_per_wave and spawn_attempts_used < spawn_attempts:
		var spawn_pos = _find_smart_spawn_position(spawn_center)
		spawn_attempts_used += 1
		
		if spawn_pos == Vector3.ZERO:
			print("🎯 Attempt %d failed, trying again..." % spawn_attempts_used)
			continue
		
		var enemy = enemy_scene.instantiate()
		add_child(enemy)
		
		# FIXED: Proper ground-level spawning
		spawn_pos.y = 2.0  # Just above ground level, not floating in sky!
		enemy.global_position = spawn_pos
		
		# Connect death signal
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_enemy_died)
		
		enemies_alive.append(enemy)
		enemies_spawned += 1
		
		print("🎯 Enemy %d spawned at %s (Distance from player: %.1f)" % [
			enemies_spawned, 
			spawn_pos, 
			spawn_pos.distance_to(player.global_position)
		])
	
	print("✅ Wave %d complete: %d/%d enemies spawned!" % [current_wave, enemies_spawned, enemies_per_wave])

# === NEW: SMART SPAWN CENTER CALCULATION ===
func _calculate_smart_spawn_center() -> Vector3:
	"""Calculate the best position to spawn enemies around"""
	var now = Time.get_ticks_msec() / 1000.0
	
	# Cache the spawn center for performance
	if now - last_spawn_update_time > SPAWN_CENTER_UPDATE_INTERVAL:
		if use_player_position or latest_room_position == Vector3.ZERO:
			# Prioritize player position for immediate action
			spawn_center_cache = player.global_position
			print("🎯 Using PLAYER position as spawn center")
		else:
			# Use room center but adjust toward player
			var room_to_player = player.global_position - latest_room_position
			spawn_center_cache = latest_room_position + (room_to_player * 0.3)  # 30% toward player
			print("🎯 Using ADJUSTED room position as spawn center")
		
		last_spawn_update_time = now
	
	return spawn_center_cache

# === NEW: SMART SPAWN POSITIONING ===
func _find_smart_spawn_position(spawn_center: Vector3) -> Vector3:
	"""Find optimal spawn position with multiple strategies"""
	
	# Strategy 1: Ring around player (best for combat)
	var ring_position = _try_ring_spawn(spawn_center)
	if ring_position != Vector3.ZERO:
		return ring_position
	
	# Strategy 2: Random in range (fallback)
	var random_position = _try_random_spawn(spawn_center)
	if random_position != Vector3.ZERO:
		return random_position
	
	# Strategy 3: Emergency spawn (last resort)
	return _emergency_spawn(spawn_center)

func _try_ring_spawn(center: Vector3) -> Vector3:
	"""Try to spawn in a ring around the center for balanced encounters"""
	for attempt in range(10):
		var angle = randf() * TAU
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		
		var spawn_pos = center + Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)
		
		if _is_spawn_position_valid(spawn_pos):
			return spawn_pos
	
	return Vector3.ZERO

func _try_random_spawn(center: Vector3) -> Vector3:
	"""Random spawn within range as fallback"""
	for attempt in range(15):
		var random_offset = Vector3(
			randf_range(-spawn_radius_max, spawn_radius_max),
			0,
			randf_range(-spawn_radius_max, spawn_radius_max)
		)
		
		var spawn_pos = center + random_offset
		
		if _is_spawn_position_valid(spawn_pos):
			return spawn_pos
	
	return Vector3.ZERO

func _emergency_spawn(center: Vector3) -> Vector3:
	"""Emergency spawn if all else fails"""
	print("⚠️ Using emergency spawn!")
	var emergency_pos = center + Vector3(
		randf_range(-2.0, 2.0),
		0,
		randf_range(-2.0, 2.0)
	)
	return emergency_pos

# === IMPROVED VALIDATION ===
func _is_spawn_position_valid(pos: Vector3) -> bool:
	"""Enhanced validation for spawn positions"""
	if not player:
		return false
	
	var player_distance = pos.distance_to(player.global_position)
	
	# Must be within our spawn range
	if player_distance < spawn_radius_min or player_distance > max_distance_from_player:
		return false
	
	# Check for overlap with existing enemies
	for enemy in enemies_alive:
		if is_instance_valid(enemy) and pos.distance_to(enemy.global_position) < 1.5:
			return false
	
	# NEW: Simple terrain check (avoid walls if possible)
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain and terrain.has_method("_is_valid_pos"):
		var grid_x = int((pos.x / 2.0) + 30)  # Assuming 60x60 map
		var grid_y = int((pos.z / 2.0) + 30)
		if not terrain._is_valid_pos(grid_x, grid_y):
			return false
	
	return true

# === WAVE PROGRESSION (Improved) ===
func _on_enemy_died() -> void:
	# Clean up dead enemies
	enemies_alive = enemies_alive.filter(func(e): return is_instance_valid(e) and not ("is_dead" in e and e.is_dead))
	
	print("🎯 Enemy died! Remaining: %d" % enemies_alive.size())
	
	if enemies_alive.size() == 0:
		print("🎉 Wave %d COMPLETE!" % current_wave)
		wave_completed.emit(current_wave)  # Signal for room generation
		
		current_wave += 1
		if current_wave <= max_waves:
			print("⏳ Next wave in %.1f seconds..." % wave_delay)
			wave_timer.start()
		else:
			print("🏆 ALL WAVES COMPLETE!")
			all_waves_complete.emit()

func _on_wave_timer_timeout() -> void:
	start_wave()

# === ROOM SYSTEM INTEGRATION (Improved) ===
func set_newest_spawning_room(room_rect: Rect2) -> void:
	var center = room_rect.position + room_rect.size * 0.5
	latest_room_position = Vector3(center.x, 2.0, center.y)
	print("🎯 Updated room position to: ", latest_room_position)
	
	# Start first wave if needed
	if current_wave == 1 and enemies_alive.size() == 0:
		start_wave()

func update_latest_room(pos: Vector3) -> void:
	latest_room_position = pos
	print("🎯 Updated latest_room_position to: ", pos)
	
	if current_wave == 1 and enemies_alive.size() == 0:
		start_wave()

func start_wave_system() -> void:
	if enemies_alive.size() == 0:
		current_wave = 1
		start_wave()

# === UI/DEBUG INFO (Improved) ===
func get_wave_info() -> Dictionary:
	var wave_active = enemies_alive.size() > 0
	var is_spawning = false  # Could track this during spawn_wave() if needed
	
	return {
		"current_wave": current_wave,
		"max_waves": max_waves,
		"current_enemies": enemies_alive.size(),
		"enemies_spawned": enemies_per_wave if wave_active else 0,
		"total_enemies_for_wave": enemies_per_wave,
		"wave_active": wave_active,
		"is_spawning": is_spawning,
		"spawn_center": spawn_center_cache,
		"player_position": player.global_position if player else Vector3.ZERO
	}

# === DEBUG FUNCTIONS ===
func force_next_wave():
	"""Debug function to skip to next wave"""
	for enemy in enemies_alive:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies_alive.clear()
	_on_enemy_died()

func get_spawn_debug_info() -> String:
	"""Get debug info about spawning"""
	# Returns a formatted string with spawn center, player position, and distance
	var player_pos := player.global_position if player else Vector3.ZERO
	var distance := spawn_center_cache.distance_to(player_pos) if player else -1.0
	return "Spawn Center: %s | Player: %s | Distance: %.1f" % [
		spawn_center_cache,
		player_pos,
		distance
	]
