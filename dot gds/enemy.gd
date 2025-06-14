# enemy.gd - FIXED: Wall-aware enemy with proper collision prevention
extends CharacterBody3D

signal enemy_died

# Combat stats
@export var health = 30
@export var max_health = 30
@export var speed = 2.0
@export var chase_range = 100.0
@export var attack_range = 1.5
@export var attack_damage = 5
@export var attack_cooldown = 2.0

# Physics settings
@export var slide_force = 1.5
@export var separation_distance = 1.2
@export var max_slide_speed = 2.0
@export var slide_damping = 0.85

# Knockback system
@export var knockback_force = 15.0
@export var knockback_duration = 0.8
var knockback_velocity = Vector3.ZERO
var knockback_timer = 0.0
var is_being_knocked_back = false

# Spawn settings
var spawn_timer = 0.0
var is_spawn_complete = false
const SPAWN_DURATION = 0.4

# Core state
var player: CharacterBody3D
var last_attack_time = 0.0
var is_dead = false
var is_jumping = false

# Jump attack variables
var jump_start_pos = Vector3.ZERO
var jump_target_pos = Vector3.ZERO
var jump_timer = 0.0
var jump_duration = 0.6

# AI state
enum AIState { SPAWNING, IDLE, PATROL, CHASE, ATTACK }
var current_state = AIState.SPAWNING
var state_timer = 0.0
var patrol_target = Vector3.ZERO
var home_position = Vector3.ZERO

# Scene components
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var original_mesh_scale: Vector3

# Performance cache
var player_check_timer = 0.0
const PLAYER_CHECK_INTERVAL = 0.2
var cached_distance = 999.0
var cached_player_pos = Vector3.ZERO

# Physics
var slide_velocity = Vector3.ZERO
var last_valid_position = Vector3.ZERO

func _ready():
	print("🔄 Enemy: Starting initialization...")
	_connect_to_scene_nodes()
	_setup_physics()
	call_deferred("_delayed_init")

func _connect_to_scene_nodes():
	mesh_instance = get_node("MeshInstance3D")
	collision_shape = get_node("CollisionShape3D")
	original_mesh_scale = mesh_instance.scale if mesh_instance and is_instance_valid(mesh_instance) else Vector3.ONE
	if mesh_instance and is_instance_valid(mesh_instance):
		mesh_instance.visible = true
		print("✅ Enemy: Connected to MeshInstance3D")
	else:
		print("❌ Enemy: Could not find MeshInstance3D!")
	if collision_shape and is_instance_valid(collision_shape):
		print("✅ Enemy: Connected to CollisionShape3D")
	else:
		print("❌ Enemy: Could not find CollisionShape3D!")

func _setup_physics():
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1 | 2
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	max_health = health
	velocity = Vector3.ZERO

func _delayed_init():
	await get_tree().process_frame
	_find_player()
	_correct_spawn_position()
	_set_home()
	print("✅ Enemy initialization complete")

func _find_player():
	player = get_tree().get_first_node_in_group("player")
	if player:
		cached_player_pos = player.global_position

func _correct_spawn_position():
	if global_position.y < 1.0:
		global_position.y = 2.0
	velocity.y = 0
	for i in range(10):
		_apply_gravity(get_physics_process_delta_time())
		move_and_slide()
		if is_on_floor():
			break

func _set_home():
	await get_tree().create_timer(0.5).timeout
	home_position = global_position
	patrol_target = home_position

func _physics_process(delta):
	if not enabled:
		velocity = Vector3.ZERO
		if mesh_instance and is_instance_valid(mesh_instance):
			mesh_instance.visible = false
		return
	# ...existing code...

func _prevent_wall_clipping():
	var terrain = get_tree().get_first_node_in_group("terrain")
	var map_size = Vector2(60, 60)
	if terrain and "map_size" in terrain:
		map_size = terrain.map_size
	var grid_x = int((global_position.x / 2.0) + (map_size.x / 2))
	var grid_y = int((global_position.z / 2.0) + (map_size.y / 2))
	var is_valid = terrain._is_valid_pos(grid_x, grid_y) if terrain and terrain.has_method("_is_valid_pos") else true
	if is_valid:
		last_valid_position = global_position
	else:
		var try_offsets = [
			Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,1), Vector3(0,0,-1),
			Vector3(1,0,1), Vector3(-1,0,1), Vector3(1,0,-1), Vector3(-1,0,-1),
			Vector3(2,0,0), Vector3(-2,0,0), Vector3(0,0,2), Vector3(0,0,-2)
		]
		var found = false
		for offset in try_offsets:
			if found: break
			for dist in [0.5, 1.0, 1.5, 2.0]:
				var test_pos = global_position + offset.normalized() * dist
				var test_grid_x = int((test_pos.x / 2.0) + (map_size.x / 2))
				var test_grid_y = int((test_pos.z / 2.0) + (map_size.y / 2))
				if terrain and terrain.has_method("_is_valid_pos") and terrain._is_valid_pos(test_grid_x, test_grid_y):
					global_position = test_pos
					last_valid_position = test_pos
					found = true
					break
		if not found:
			global_position = last_valid_position
		velocity = Vector3.ZERO
		slide_velocity = Vector3.ZERO
	if global_position.y < 0.8:
		global_position.y = 0.8
		velocity.y = max(0, velocity.y)
		slide_velocity = Vector3.ZERO

func _handle_spawn(delta):
	spawn_timer += delta
	velocity = Vector3.ZERO
	if mesh_instance and is_instance_valid(mesh_instance):
		var progress = spawn_timer / SPAWN_DURATION
		mesh_instance.scale = original_mesh_scale * lerp(0.1, 1.0, progress)
	if spawn_timer >= SPAWN_DURATION:
		is_spawn_complete = true
		if mesh_instance:
			mesh_instance.scale = original_mesh_scale
		current_state = AIState.IDLE

func _handle_knockback(delta):
	if knockback_timer > 0:
		knockback_timer -= delta
		var decay_factor = knockback_timer / knockback_duration
		velocity.x = knockback_velocity.x * decay_factor
		velocity.z = knockback_velocity.z * decay_factor
		if knockback_timer <= 0:
			knockback_velocity = Vector3.ZERO
			is_being_knocked_back = false

func _apply_knockback_from_player():
	if not _is_player_valid():
		return
	var direction = (global_position - player.global_position)
	direction.y = 0
	direction = direction.normalized() if direction.length() > 0.1 else Vector3.RIGHT
	knockback_velocity = direction * knockback_force
	knockback_timer = knockback_duration
	is_being_knocked_back = true
	current_state = AIState.IDLE

func _handle_enemy_separation(delta):
	var enemies = get_tree().get_nodes_in_group("enemies")
	var separation_force = Vector3.ZERO
	var terrain = get_tree().get_first_node_in_group("terrain")
	var map_size = Vector2(60, 60)
	if terrain and "map_size" in terrain:
		map_size = terrain.map_size
	for other in enemies:
		if other == self or not is_instance_valid(other): continue
		if "is_dead" in other and other.is_dead: continue
		var distance = global_position.distance_to(other.global_position)
		if distance < separation_distance and distance > 0.1:
			var direction = (global_position - other.global_position)
			direction.y = 0
			direction = direction.normalized()
			var force_strength = (separation_distance - distance) * 0.5
			var force = direction * force_strength
			if not _would_hit_wall(global_position, direction, map_size, terrain):
				separation_force += force
	slide_velocity += separation_force * slide_force * delta * 0.3
	var max_slide = max_slide_speed * 0.7
	slide_velocity.x = clamp(slide_velocity.x, -max_slide, max_slide)
	slide_velocity.z = clamp(slide_velocity.z, -max_slide, max_slide)

func _would_hit_wall(pos: Vector3, dir: Vector3, map_size: Vector2, terrain) -> bool:
	if not terrain or not terrain.has_method("_is_valid_pos"):
		return false
	var test_pos = pos + dir.normalized() * 0.5
	var test_grid_x = int((test_pos.x / 2.0) + (map_size.x / 2))
	var test_grid_y = int((test_pos.z / 2.0) + (map_size.y / 2))
	return not terrain._is_valid_pos(test_grid_x, test_grid_y)

func _apply_sliding(delta):
	velocity.x += slide_velocity.x * delta
	velocity.z += slide_velocity.z * delta
	slide_velocity *= slide_damping
	if slide_velocity.length() < 0.1:
		slide_velocity = Vector3.ZERO

func _update_cache(delta):
	player_check_timer += delta
	if player_check_timer >= PLAYER_CHECK_INTERVAL and _is_player_valid():
		cached_player_pos = player.global_position
		cached_distance = global_position.distance_to(player.global_position)
		player_check_timer = 0.0

func _is_player_valid() -> bool:
	return player and is_instance_valid(player) and not ("is_dead" in player and player.is_dead)

func _handle_ai(delta):
	state_timer += delta
	match current_state:
		AIState.IDLE:
			velocity = Vector3.ZERO
			_add_wobble()
			if cached_distance <= chase_range:
				current_state = AIState.CHASE
			elif state_timer >= 2.0:
				current_state = AIState.PATROL
				_set_patrol_target()
		AIState.PATROL:
			if cached_distance <= chase_range:
				current_state = AIState.CHASE
			else:
				_move_to_target(patrol_target, speed * 0.5)
				if global_position.distance_to(patrol_target) < 1.0 or state_timer > 4.0:
					_set_patrol_target()
					state_timer = 0.0
		AIState.CHASE:
			if cached_distance > chase_range * 1.5:
				current_state = AIState.IDLE
			elif cached_distance <= attack_range:
				current_state = AIState.ATTACK
			else:
				_move_toward_player()
				_face_player()
		AIState.ATTACK:
			velocity = Vector3.ZERO
			_face_player()
			if cached_distance > attack_range * 1.2:
				current_state = AIState.CHASE
			else:
				_try_attack()

func _set_patrol_target():
	var angle = randf() * TAU
	var distance = randf_range(1.0, 3.0)
	patrol_target = home_position + Vector3(cos(angle) * distance, 0, sin(angle) * distance)

func _move_to_target(target: Vector3, move_speed: float):
	var direction = (target - global_position)
	direction.y = 0
	if direction.length() > 0.8:
		direction = direction.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity = Vector3.ZERO

func _move_toward_player():
	if not _is_player_valid():
		return
	var direction = (cached_player_pos - global_position)
	direction.y = 0
	direction = direction.normalized()
	# Ensure -Z is forward for enemy movement
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

func _face_player():
	if not _is_player_valid() or is_being_knocked_back:
		return
	var direction_to_player = (cached_player_pos - global_position)
	direction_to_player.y = 0
	if direction_to_player.length() > 0.1:
		direction_to_player = direction_to_player.normalized()
		# Ensure -Z is forward for facing
		var target_rotation_y = atan2(direction_to_player.x, direction_to_player.z)
		var rotation_speed = 6.0
		rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * get_physics_process_delta_time())

func _add_wobble():
	if not mesh_instance or not is_instance_valid(mesh_instance):
		return
	var time = Time.get_ticks_msec() * 0.001
	var wobble = sin(time * 3.0) * 0.05
	mesh_instance.scale.y = original_mesh_scale.y + wobble

func _try_attack():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time >= attack_cooldown:
		_start_jump_attack()
		last_attack_time = current_time

func _start_jump_attack():
	if not _is_player_valid() or is_jumping:
		return
	var direction = (cached_player_pos - global_position)
	direction.y = 0
	direction = direction.normalized()
	is_jumping = true
	jump_start_pos = global_position
	jump_target_pos = global_position + direction * 1.2
	jump_timer = 0.0

func _handle_jump_movement(delta):
	if not is_jumping:
		return
	jump_timer += delta
	var progress = jump_timer / jump_duration
	if progress >= 1.0:
		_complete_jump_attack()
		return
	var horizontal = jump_start_pos.lerp(jump_target_pos, progress)
	var height = jump_start_pos.y + (2.0 * sin(progress * PI))
	global_position = Vector3(horizontal.x, height, horizontal.z)

func _complete_jump_attack():
	is_jumping = false
	jump_timer = 0.0
	global_position = Vector3(jump_target_pos.x, jump_start_pos.y, jump_target_pos.z)
	if _is_player_valid() and global_position.distance_to(player.global_position) <= attack_range * 1.5:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage, self)
	current_state = AIState.IDLE

func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

func take_damage(amount: int):
	if is_dead:
		return
	var damage_system = get_tree().get_first_node_in_group("damage_numbers")
	if damage_system:
		damage_system.show_damage(amount, self)
	health -= amount
	_apply_knockback_from_player()
	_create_damage_wobble()
	if health <= 0:
		die()

func _create_damage_wobble():
	if not mesh_instance or not is_instance_valid(mesh_instance):
		return
	var tween = create_tween()
	tween.set_parallel(true)
	var punch_scale = original_mesh_scale * Vector3(0.5, 2.0, 0.5)
	tween.tween_property(mesh_instance, "scale", punch_scale, 0.05)
	var overshoot = original_mesh_scale * Vector3(1.8, 0.4, 1.8)
	tween.tween_property(mesh_instance, "scale", overshoot, 0.08).set_delay(0.05)
	tween.tween_property(mesh_instance, "scale", original_mesh_scale, 0.15).set_delay(0.13)

func die():
	if is_dead:
		return
	is_dead = true
	if LootManager:
		LootManager.drop_enemy_loot(global_position, self)
	if randf() < 0.05:
		_drop_weapon()
	enemy_died.emit()
	queue_free()

func _drop_weapon():
	if LootManager and LootManager.has_method("drop_weapon"):
		if "weapon_resource" in self and self.weapon_resource:
			LootManager.drop_weapon(global_position, self.weapon_resource)
		else:
			LootManager.drop_weapon(global_position)


@export var enabled := true
# ...existing code...