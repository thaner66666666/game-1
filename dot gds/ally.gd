# ally.gd - Simple ally that follows player and attacks enemies
extends CharacterBody3D

# Basic stats
@export var speed := 4.0
@export var follow_distance := 3.0
@export var attack_range := 2.5
@export var attack_damage := 15
@export var attack_cooldown := 1.5
@export var health := 100
@export var max_health := 100

# References

# Target position for roaming
var roaming_target_position: Vector3 = Vector3.ZERO

# Target position for roaming
var target_position: Vector3 = Vector3(0, 0, 0)
var player: CharacterBody3D
var current_target: Node3D = null
var attack_timer := 0.0

# Visual components
var mesh_instance: MeshInstance3D
var weapon_mesh: MeshInstance3D

# Visual component references (for animations)
var left_foot: MeshInstance3D
var right_foot: MeshInstance3D
var left_hand: MeshInstance3D
var right_hand: MeshInstance3D

signal ally_added
signal ally_removed

func _find_player():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("❌ Ally: Player not found!")

func _create_visual():
	# Use CharacterAppearanceManager to create random appearance
	print("🎨 Creating procedural ally appearance...")
	
	# Get the MeshInstance3D node from the scene
	mesh_instance = get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		# Create it if it doesn't exist
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)

	# Ensure the MeshInstance3D has a valid mesh
	if not mesh_instance.mesh:
		mesh_instance.mesh = SphereMesh.new()  # Default to a sphere mesh

	# Ensure the MeshInstance3D has a valid material
	if not mesh_instance.material_override:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.4, 0.6, 1.0)  # Bluish tint for allies
		mesh_instance.material_override = material
	
	# Generate random character appearance
	var config = CharacterGenerator.generate_random_character_config()
	
	# Apply blue-tinted skin for allies
	config["skin_tone"] = Color(0.4, 0.6, 1.0)  # Bluish tint
	
	# Apply the generated appearance using CharacterAppearanceManager
	CharacterAppearanceManager.create_player_appearance(self, config)

func _setup_body_part_references():
	# Find feet for walking animation
	left_foot = get_node_or_null("LeftFoot")
	right_foot = get_node_or_null("RightFoot")

func _physics_process(delta):
	attack_timer = max(0, attack_timer - delta)

	# Find nearest enemy
	current_target = _find_nearest_enemy()

	if current_target and global_position.distance_to(current_target.global_position) <= attack_range:
		# Attack enemy
		_attack_enemy()
		velocity = Vector3.ZERO
	else:
		# --- Enhanced Patrolling/Orbiting Logic ---
		if player:
			var orbit_radius = follow_distance * 1.5 + randf() * 1.5
			var orbit_speed = 1.0 + randf() * 0.5
			# Orbit angle based on time and unique offset per ally
			var orbit_offset = int(get_instance_id()) % 360
			var angle = (Time.get_ticks_msec() * 0.0005 * orbit_speed + orbit_offset) % (PI * 2)
			var orbit_pos = player.global_position + Vector3(cos(angle), 0, sin(angle)) * orbit_radius
			# Smoothly pick a new target position near the orbit
			if not target_position or global_position.distance_to(target_position) < 0.5 or randf() < 0.01:
				target_position = orbit_pos + Vector3(randf() - 0.5, 0, randf() - 0.5)
			var direction_to_target = (target_position - global_position).normalized()
			direction_to_target.y = 0
			# Wall avoidance: steer if about to hit a wall
			var avoid_wall = false
			var steer_angle = 0.0
			var test_distance = 1.0
			if test_move(transform, direction_to_target * test_distance):
				avoid_wall = true
				# Try left
				var left = direction_to_target.rotated(Vector3.UP, 0.5)
				if not test_move(transform, left * test_distance):
					direction_to_target = left
					steer_angle = 0.5
				else:
					# Try right
					var right = direction_to_target.rotated(Vector3.UP, -0.5)
					if not test_move(transform, right * test_distance):
						direction_to_target = right
						steer_angle = -0.5
					else:
						# If both blocked, stop
						direction_to_target = Vector3.ZERO
			# Smooth velocity for natural movement
			velocity.x = lerp(velocity.x, direction_to_target.x * speed, 0.1)
			velocity.z = lerp(velocity.z, direction_to_target.z * speed, 0.1)
			# Face movement direction
			if direction_to_target.length() > 0.1:
				look_at(global_position + direction_to_target, Vector3.UP)
		else:
			# Fallback: random roaming
			if not target_position or global_position.distance_to(target_position) < 1.0:
				target_position = global_position + Vector3(randf() * 20 - 10, 0, randf() * 20 - 10)
			var direction_to_target = (target_position - global_position).normalized()
			direction_to_target.y = 0
			velocity.x = lerp(velocity.x, direction_to_target.x * speed, 0.1)
			velocity.z = lerp(velocity.z, direction_to_target.z * speed, 0.1)

	# Improved avoidance with other allies
	var allies = get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if ally != self and is_instance_valid(ally):
			var distance_to_ally = global_position.distance_to(ally.global_position)
			if distance_to_ally < follow_distance:
				var avoidance_direction = (global_position - ally.global_position).normalized()
				velocity += avoidance_direction * speed * 0.3 * (1.0 - distance_to_ally / follow_distance)

	# Apply gravity
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	move_and_slide()

func _follow_player():
	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player > follow_distance * 10:
		# Move toward the player if too far
		var direction = (player.global_position - global_position).normalized()
		direction.y = 0
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		# Add slight randomness to movement
		velocity.x += (randf() - 0.5) * speed * 0.2
		velocity.z += (randf() - 0.5) * speed * 0.2

		# Face movement direction
		if direction.length() > 0.1:
			look_at(global_position + direction, Vector3.UP)
	else:
		# Stop when close enough
		velocity.x = (randf() - 0.5) * speed * 0.1
		velocity.z = (randf() - 0.5) * speed * 0.1

func _find_nearest_enemy() -> Node3D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_enemy: Node3D = null
	var nearest_distance := 999.0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance and distance <= attack_range * 2:
			nearest_distance = distance
			nearest_enemy = enemy
	
	return nearest_enemy

func _attack_enemy():
	if attack_timer > 0 or not current_target:
		return
	
	# Face the enemy
	var direction = (current_target.global_position - global_position)
	direction.y = 0
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
	
	# Attack
	if current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)
		print("🗡️ Ally attacked enemy for ", attack_damage, " damage!")
	
	# Play attack animation (simple weapon swing)
	_play_attack_animation()
	
	attack_timer = attack_cooldown

func _play_attack_animation():
	if not weapon_mesh:
		return
	
	var tween = create_tween()
	tween.tween_property(weapon_mesh, "rotation_degrees", Vector3(0, 0, -45), 0.1)
	tween.tween_property(weapon_mesh, "rotation_degrees", Vector3.ZERO, 0.2)

func take_damage(amount: int, attacker: Node = null):
	health -= amount
	print("🤝 Ally took ", amount, " damage! Health: ", health)

	if health <= 0:
		die()
		if attacker:
			print("💀 Ally killed by ", attacker.name)

func die():
	print("💀 Ally died! Emitting ally_removed signal.")
	emit_signal("ally_removed")
	queue_free()

func _ready():
	add_to_group("allies")
	emit_signal("ally_added")
	print("🤝 Ally added to group 'allies' and signal emitted.")
