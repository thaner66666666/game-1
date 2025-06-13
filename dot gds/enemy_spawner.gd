# enemy_spawner.gd - CLEAN REWRITE: Simple waves that work
extends Node3D

# === SIGNALS FOR INTEGRATION ===
signal wave_completed(wave_number: int)
signal all_waves_completed
signal enemy_spawned(enemy: Node3D)

# === WAVE CONFIGURATION ===
@export var max_waves: int = 10
@export var base_enemies_per_wave: int = 3
@export var enemy_increase_per_wave: int = 2
@export var wave_delay: float = 3.0

# === ENEMY SETTINGS ===
@export var enemy_scene: PackedScene
@export var spawn_distance_min: float = 4.0
@export var spawn_distance_max: float = 8.0
@export var spawn_attempts: int = 20

# === CURRENT STATE ===
var current_wave: int = 0
var enemies_alive: Array[Node3D] = []
var wave_active: bool = false
var spawning_active: bool = false

# === REFERENCES ===
var player: Node3D
var current_spawning_room: Rect2
var map_size: Vector2 = Vector2(60, 60)

# === TIMERS ===
var wave_delay_timer: Timer

func _ready():
	name = "EnemySpawner"
	add_to_group("spawner")
	print("🌊 Clean Wave System: Initializing...")
	
	_setup_system()

func _setup_system():
	"""Initialize the wave system"""
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("❌ Player not found!")
		return
	
	# Load enemy scene if not set
	if not enemy_scene:
		if ResourceLoader.exists("res://Scenes/enemy.tscn"):
			enemy_scene = load("res://Scenes/enemy.tscn")
			print("✅ Loaded enemy scene")
		else:
			print("❌ No enemy scene found!")
			return
	
	# Setup wave delay timer
	wave_delay_timer = Timer.new()
	wave_delay_timer.wait_time = wave_delay
	wave_delay_timer.one_shot = true
	wave_delay_timer.timeout.connect(_start_next_wave)
	add_child(wave_delay_timer)
	
	print("✅ Wave System ready!")

# === MAIN WAVE SYSTEM ===
func start_wave_system():
	"""PUBLIC: Start the entire wave system"""
	if current_wave == 0:
		print("🚀 Starting Wave System!")
		current_wave = 1
		_start_current_wave()

func set_newest_spawning_room(room_rect: Rect2):
	"""PUBLIC: Set the room where enemies should spawn"""
	current_spawning_room = room_rect
	print("🏠 Wave System: Set spawning room to ", room_rect)
	
	# If we haven't started waves yet, start now
	if current_wave == 0:
		start_wave_system()

func _start_current_wave():
	"""Start the current wave"""
	if wave_active:
		print("⚠️ Wave already active!")
		return
	
	print("🌊 === STARTING WAVE ", current_wave, " ===")
	
	wave_active = true
	spawning_active = true
	enemies_alive.clear()
	
	# Calculate enemies for this wave
	var total_enemies = base_enemies_per_wave + (current_wave - 1) * enemy_increase_per_wave
	print("👹 Spawning ", total_enemies, " enemies for wave ", current_wave)
	
	# Spawn all enemies for this wave
	for i in range(total_enemies):
		var enemy = _spawn_single_enemy()
		if enemy:
			enemies_alive.append(enemy)
			enemy_spawned.emit(enemy)
	
	spawning_active = false
	print("✅ Wave ", current_wave, " active with ", enemies_alive.size(), " enemies")

func _spawn_single_enemy() -> Node3D:
	"""Spawn one enemy in the current room"""
	var spawn_position = _find_spawn_position()
	if spawn_position == Vector3.ZERO:
		print("⚠️ Could not find spawn position")
		return null
	
	# Create enemy
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = spawn_position
	
	# Scale enemy for current wave
	_scale_enemy_for_wave(enemy)
	
	# Connect death signal
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))
	
	print("✅ Spawned enemy at ", spawn_position)
	return enemy

func _find_spawn_position() -> Vector3:
	"""Find a valid spawn position"""
	var spawn_center = _get_spawn_center()
	
	# Try multiple positions around the spawn center
	for attempt in range(spawn_attempts):
		var angle = randf() * TAU
		var distance = randf_range(spawn_distance_min, spawn_distance_max)
		
		var test_position = spawn_center + Vector3(
			cos(angle) * distance,
			2.0,  # Always spawn at ground level
			sin(angle) * distance
		)
		
		if _is_valid_spawn_position(test_position):
			return test_position
	
	print("⚠️ Using fallback spawn position")
	return spawn_center + Vector3(randf_range(-3, 3), 2.0, randf_range(-3, 3))

func _get_spawn_center() -> Vector3:
	"""Get the center point for spawning"""
	if current_spawning_room != Rect2():
		# Use room center
		var room_center = current_spawning_room.get_center()
		return Vector3(
			(room_center.x - map_size.x / 2) * 2.0,
			2.0,
			(room_center.y - map_size.y / 2) * 2.0
		)
	else:
		# Fallback to player position
		return player.global_position

func _is_valid_spawn_position(pos: Vector3) -> bool:
	"""Check if spawn position is valid"""
	# Check distance from player
	var player_distance = pos.distance_to(player.global_position)
	if player_distance < 2.0 or player_distance > 15.0:
		return false
	
	# Check for enemy overlap
	for enemy in enemies_alive:
		if is_instance_valid(enemy) and pos.distance_to(enemy.global_position) < 2.0:
			return false
	
	# Check terrain if available
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain and terrain.has_method("_is_valid_pos"):
		var grid_x = int((pos.x / 2.0) + (map_size.x / 2))
		var grid_y = int((pos.z / 2.0) + (map_size.y / 2))
		return terrain._is_valid_pos(grid_x, grid_y)
	
	return true

func _scale_enemy_for_wave(enemy: Node3D):
	"""Make enemies stronger each wave"""
	if not enemy:
		return
	
	# Scale health, damage, and speed based on wave
	var health_scale = 1.0 + (current_wave - 1) * 0.3  # +30% health per wave
	var damage_scale = 1.0 + (current_wave - 1) * 0.2  # +20% damage per wave
	var speed_scale = 1.0 + (current_wave - 1) * 0.1   # +10% speed per wave
	
	if "max_health" in enemy:
		enemy.max_health = int(enemy.max_health * health_scale)
		enemy.health = enemy.max_health
	
	if "attack_damage" in enemy:
		enemy.attack_damage = int(enemy.attack_damage * damage_scale)
	
	if "speed" in enemy:
		enemy.speed = enemy.speed * speed_scale

# === WAVE COMPLETION SYSTEM ===
func _on_enemy_died(enemy: Node3D):
	"""Called when an enemy dies"""
	enemies_alive.erase(enemy)
	print("💀 Enemy died! Remaining: ", enemies_alive.size())
	
	# Check if wave is complete
	if enemies_alive.size() == 0 and wave_active:
		_complete_wave()

func _complete_wave():
	"""Complete the current wave"""
	wave_active = false
	
	print("🎉 WAVE ", current_wave, " COMPLETED!")
	
	# Emit signal for room generation
	wave_completed.emit(current_wave)
	
	# Check if all waves are done
	if current_wave >= max_waves:
		print("🏆 ALL WAVES COMPLETED!")
		all_waves_completed.emit()
		return
	
	# Start delay for next wave
	print("⏳ Next wave starts in ", wave_delay, " seconds...")
	wave_delay_timer.start()

func _start_next_wave():
	"""Start the next wave after delay"""
	current_wave += 1
	_start_current_wave()

# === PUBLIC API FOR UI AND OTHER SYSTEMS ===
func get_wave_info() -> Dictionary:
	"""Get current wave information for UI"""
	var total_enemies_for_wave = base_enemies_per_wave + (current_wave - 1) * enemy_increase_per_wave
	
	return {
		"current_wave": current_wave,
		"max_waves": max_waves,
		"current_enemies": enemies_alive.size(),
		"enemies_spawned": total_enemies_for_wave if wave_active else 0,
		"total_enemies_for_wave": total_enemies_for_wave,
		"wave_active": wave_active,
		"is_spawning": spawning_active
	}

# === DEBUG FUNCTIONS ===
func force_next_wave():
	"""Debug: Skip to next wave"""
	for enemy in enemies_alive:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies_alive.clear()
	if wave_active:
		_complete_wave()

func force_start_waves():
	"""Debug: Force start wave system"""
	if current_wave == 0:
		start_wave_system()
