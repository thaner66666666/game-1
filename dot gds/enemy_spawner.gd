# EnemySpawner.gd
# Purpose: Spawns waves of enemies at valid positions, tracks wave progress, and ensures beginner-friendly code.
# Author: Thane
# Last Modified: June 12, 2025

extends Node3D

# === EXPORTED VARIABLES (Inspector-editable) ===
@export var enemy_scene: PackedScene # The enemy scene to spawn
@export var spawn_radius: float = 4.0 # How far from the center to spawn enemies (close)
@export var min_distance_from_player: float = 1.0 # Minimum distance from player (must be <= spawn_radius)
@export var spawn_attempts: int = 30 # Attempts to find a valid spawn position
@export var enemies_per_wave: int = 5 # Number of enemies per wave
@export var wave_delay: float = 5.0 # Delay between waves (seconds)

# === PRIVATE VARIABLES ===
var player: Node3D = null # Reference to the player node
var latest_room_position: Vector3 = Vector3.ZERO # Center of the current room
var current_wave: int = 1 # Current wave number
var wave_timer: Timer = null # Timer for wave delay
var enemies_alive: Array = [] # List of currently alive enemies
var max_waves: int = 5 # Maximum number of waves

# === GODOT BUILT-IN FUNCTIONS ===
func _ready() -> void:
	# Find the player node in the scene
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("Player not found in group 'player'")
		return

	# Load fallback enemy scene if not set
	if enemy_scene == null:
		var fallback_path = "res://Scenes/enemy.tscn"
		if ResourceLoader.exists(fallback_path):
			enemy_scene = load(fallback_path)
			print("[EnemySpawner] Loaded fallback enemy scene.")
		else:
			push_error("[EnemySpawner] No enemy scene set and fallback not found!")
			return

	# Set up the wave timer
	wave_timer = Timer.new()
	wave_timer.wait_time = wave_delay
	wave_timer.one_shot = true
	wave_timer.timeout.connect(_on_wave_timer_timeout)
	add_child(wave_timer)

	# Do NOT start the first wave here. Wait until the room is set up and update_latest_room() is called.
	# Call start_wave() after update_latest_room() in your room setup code.

# === WAVE SYSTEM ===
func start_wave() -> void:
	# Spawns a new wave of enemies
	if enemy_scene == null:
		push_error("Enemy scene not set!")
		return

	print("[EnemySpawner] Spawning wave %d" % current_wave)
	enemies_alive.clear()

	var used_positions: Array = []

	# Always use latest_room_position if set, otherwise use player's position
	var spawn_center = latest_room_position
	if spawn_center == Vector3.ZERO and player:
		spawn_center = player.global_position
		print("[EnemySpawner] Using player position as spawn center: ", spawn_center)
	elif spawn_center != Vector3.ZERO:
		print("[EnemySpawner] Using latest_room_position as spawn center: ", spawn_center)
	else:
		print("[EnemySpawner] WARNING: No valid spawn center found!")

	for i in range(enemies_per_wave):
		var spawn_pos = _find_valid_spawn_position(used_positions, spawn_center)
		if spawn_pos == Vector3.ZERO:
			print("[EnemySpawner] Could not find valid spawn position for enemy %d" % i)
			continue
		print("[EnemySpawner] Spawning enemy %d at %s" % [i, spawn_pos])
		var enemy = enemy_scene.instantiate()
		add_child(enemy)
		# Ensure enemy spawns at a visible height
		spawn_pos.y = max(spawn_pos.y, 2.0)
		enemy.global_position = spawn_pos
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_enemy_died)
		enemies_alive.append(enemy)
		used_positions.append(spawn_pos)
		# Print the enemy's final position after all spawn logic
		print("[EnemySpawner] Enemy %d final position: %s" % [i, enemy.global_position])

# Ensure latest_room_position is updated when the room changes
func update_latest_room(pos: Vector3) -> void:
	latest_room_position = pos
	print("[EnemySpawner] Updated latest_room_position to: ", pos)
	# Start the first wave after the room is set up
	if current_wave == 1 and enemies_alive.size() == 0:
		start_wave()

# === ROOM SYSTEM INTEGRATION ===
func set_newest_spawning_room(room_rect: Rect2) -> void:
	# Use the center of the room rectangle as the spawn center, with a safe Y value
	var center = room_rect.position + room_rect.size * 0.5
	update_latest_room(Vector3(center.x, 2.0, center.y))

func start_wave_system() -> void:
	# Called by main_scene_setup.gd to start the wave system
	if enemies_alive.size() == 0:
		current_wave = 1
		start_wave()

# === SPAWN POSITION LOGIC ===
func _find_valid_spawn_position(used_positions: Array, spawn_center: Vector3) -> Vector3:
	# Tries to find a valid, non-overlapping spawn position around spawn_center
	var min_dist = min_distance_from_player
	var max_dist = spawn_radius
	if min_dist > max_dist:
		min_dist = max_dist * 0.5 # fallback to half radius if misconfigured
	for attempt in range(spawn_attempts):
		var angle = randf() * TAU
		var distance = randf_range(min_dist, max_dist)
		var offset = Vector3(cos(angle), 0, sin(angle)) * distance
		var spawn_pos = spawn_center + offset
		spawn_pos.y = randf_range(15.0, 20.0) # Spawn in the air between 15 and 20
		if _is_position_valid(spawn_pos, used_positions):
			return spawn_pos
	return Vector3.ZERO # No valid position found

func _is_position_valid(pos: Vector3, used_positions: Array) -> bool:
	# Checks if the position is far enough from the player and other enemies
	if player and pos.distance_to(player.global_position) < min_distance_from_player:
		return false
	for other_pos in used_positions:
		if pos.distance_to(other_pos) < 2.0:
			return false
	return true

# === ENEMY DEATH & WAVE PROGRESSION ===
func _on_enemy_died() -> void:
	# Remove dead enemies from the list
	enemies_alive = enemies_alive.filter(func(e): return e != null and not e.is_queued_for_deletion())
	if enemies_alive.size() == 0:
		print("[EnemySpawner] Wave %d complete!" % current_wave)
		current_wave += 1
		if current_wave <= max_waves:
			wave_timer.start()
		else:
			print("[EnemySpawner] All waves complete!")

func _on_wave_timer_timeout() -> void:
	# Called when the wave timer finishes
	start_wave()

# === OPTIONAL: WAVE INFO FOR UI ===
func get_wave_info() -> Dictionary:
	# Track if a wave is active (enemies alive)
	var wave_active = enemies_alive.size() > 0
	# Track if currently spawning (for now, always false after start_wave finishes)
	var is_spawning = false # You can set this to true during spawn loop if you want more detail
	return {
		"current_wave": current_wave,
		"max_waves": max_waves,
		"current_enemies": enemies_alive.size(),
		"enemies_spawned": enemies_per_wave if wave_active else 0,
		"total_enemies_for_wave": enemies_per_wave,
		"wave_active": wave_active,
		"is_spawning": is_spawning
	}
