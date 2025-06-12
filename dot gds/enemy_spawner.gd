extends Node3D

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 12.0
@export var min_distance_from_player: float = 10.0
@export var spawn_attempts: int = 30
@export var airborne_spawn_chance: float = 0.3
@export var airborne_height_range := Vector2(4.0, 6.0)
@export var enemies_per_wave: int = 5
@export var wave_delay: float = 5.0

var player: Node3D
var latest_room_position: Vector3 = Vector3.ZERO
var current_wave: int = 1
var wave_timer: Timer

# --- Wave System Interface ---
var wave_active: bool = false
var is_spawning: bool = false
var enemies_spawned: int = 0
var total_enemies_for_wave: int = 0
var max_waves: int = 5

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("Player not found in group 'player'")
	
	wave_timer = Timer.new()
	wave_timer.wait_time = wave_delay
	wave_timer.one_shot = true
	wave_timer.timeout.connect(spawn_wave)
	add_child(wave_timer)

func spawn_wave():
	for i in range(enemies_per_wave):
		var spawn_position = _get_valid_spawn_position()
		if spawn_position != Vector3.ZERO:
			if enemy_scene:
				var enemy = enemy_scene.instantiate()
				enemy.global_position = spawn_position
				add_child(enemy)
			else:
				push_error("enemy_scene is null! Assign a PackedScene in the inspector.")
	wave_timer.start()

func _get_valid_spawn_position() -> Vector3:
	for attempt in range(spawn_attempts):
		var angle = randf() * TAU
		var distance = randf_range(min_distance_from_player, spawn_radius)
		var offset = Vector3(cos(angle), 0, sin(angle)) * distance
		var spawn_pos = latest_room_position + offset

		# Possibly spawn above for drop-in effect
		if randf() < airborne_spawn_chance:
			spawn_pos.y += randf_range(airborne_height_range.x, airborne_height_range.y)
		else:
			spawn_pos.y += 1.0  # basic floor offset

		if _is_position_valid(spawn_pos):
			return spawn_pos

	print("⚠️ Fallback spawn: using last known room center")
	return latest_room_position + Vector3(0, 1, 0)

func _is_position_valid(pos: Vector3) -> bool:
	if not player:
		return true
	if pos.distance_to(player.global_position) < min_distance_from_player:
		return false
	# Optional: Add raycast or navigation check here
	return true

func update_latest_room(pos: Vector3):
	latest_room_position = pos

# --- Wave System Interface ---
func get_wave_info() -> Dictionary:
	return {
		"current_wave": current_wave,
		"max_waves": max_waves,
		"current_enemies": get_tree().get_nodes_in_group("enemies").size(),
		"enemies_spawned": enemies_spawned,
		"total_enemies_for_wave": total_enemies_for_wave,
		"wave_active": wave_active,
		"is_spawning": is_spawning
	}

func start_wave_system():
	current_wave = 1
	wave_active = true
	is_spawning = false
	enemies_spawned = 0
	total_enemies_for_wave = enemies_per_wave
	spawn_wave()

func set_newest_spawning_room(room_rect):
	# room_rect is a Rect2, use its center for latest_room_position
	if room_rect:
		var center = room_rect.center
		latest_room_position = Vector3(center.x, 1, center.y)
	else:
		latest_room_position = Vector3.ZERO
