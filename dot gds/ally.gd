# ally.gd - Complete rewrite with combat animations
extends CharacterBody3D

# === STATS AND CONFIGURATION ===
@export var speed := 3.5
@export var follow_distance := 4.0
@export var attack_range := 2.5
@export var attack_damage := 20
@export var attack_cooldown := 1.2
@export var max_health := 80
@export var current_health := 80

# === AI BEHAVIOR SETTINGS ===
@export var detection_range := 8.0
@export var orbit_radius := 2.5
@export var orbit_speed := 0.8
@export var separation_distance := 1.5

# === REFERENCES ===
var player: CharacterBody3D
var current_target: Node3D = null

# === STATE MANAGEMENT ===
enum AllyState { FOLLOWING, ATTACKING, MOVING_TO_TARGET, DEAD }
var current_state := AllyState.FOLLOWING
var attack_timer := 0.0
var orbit_angle := 0.0
var target_position := Vector3.ZERO

# === VISUAL COMPONENTS ===
var mesh_instance: MeshInstance3D
var left_hand: MeshInstance3D
var right_hand: MeshInstance3D

# === ANIMATION SYSTEM ===
var animation_player: AnimationPlayer
var is_attacking := false
var last_facing_direction := Vector3.FORWARD

# === SIGNALS ===
signal ally_died
signal ally_spawned

func _ready():
	print("🤝 Ally: Starting complete initialization...")
	add_to_group("allies")
	
	# Setup physics
	collision_layer = 8  # Ally layer
	collision_mask = 1 | 2  # World + Enemies
	
	# Initialize health
	current_health = max_health
	
	# Setup unique orbit offset for this ally
	orbit_angle = randf() * TAU
	
	# Initialize systems
	call_deferred("_initialize_systems")

func _initialize_systems():
	"""Initialize all ally systems in proper order"""
	_find_player()
	_create_visual_character()
	
	# Wait an extra frame to ensure hands are fully created
	await get_tree().process_frame
	await get_tree().process_frame
	
	_setup_animation_system()
	_setup_combat_system()
	
	print("✅ Ally: Fully initialized with all systems!")
	emit_signal("ally_spawned")

func _find_player():
	"""Find and cache player reference"""
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("❌ Ally: Player not found!")
		return
	
	# Set initial target position near player
	target_position = player.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	print("✅ Ally: Found player and set initial position")

func _create_visual_character():
	"""Create ally appearance using CharacterAppearanceManager"""
	# Ensure we have a MeshInstance3D
	mesh_instance = get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)
	
	# Create hand anchor nodes like the player has
	var left_hand_anchor = Node3D.new()
	left_hand_anchor.name = "LeftHandAnchor"
	left_hand_anchor.position = Vector3(-0.44, -0.2, 0)
	add_child(left_hand_anchor)

	var right_hand_anchor = Node3D.new()
	right_hand_anchor.name = "RightHandAnchor"
	right_hand_anchor.position = Vector3(0.44, -0.2, 0)
	add_child(right_hand_anchor)

	print("✅ Ally: Created hand anchor nodes")
	
	# Generate random character with ally-specific coloring
	var config = CharacterGenerator.generate_random_character_config()
	config["skin_tone"] = Color(0.7, 0.8, 1.0)  # Slightly blue-tinted for allies
	
	# Apply appearance
	CharacterAppearanceManager.create_player_appearance(self, config)
	
	# Store hand references for weapon system - with debug
	await get_tree().process_frame  # Wait one frame for hands to be created
	left_hand = get_node_or_null("LeftHandAnchor/LeftHand")
	right_hand = get_node_or_null("RightHandAnchor/RightHand")
	
	print("🤝 Ally hand check - Left: ", left_hand != null, " Right: ", right_hand != null)
	if left_hand:
		print("🤝 Left hand path: ", left_hand.get_path())
	if right_hand:
		print("🤝 Right hand path: ", right_hand.get_path())
	
	print("✅ Ally: Character appearance created")

func _setup_animation_system():
	"""Setup animation player for combat animations"""
	animation_player = AnimationPlayer.new()
	animation_player.name = "AllyAnimationPlayer"
	add_child(animation_player)
	
	# Create attack animation
	_create_attack_animation()
	
	print("✅ Ally: Animation system ready")

func _create_attack_animation():
	"""Create a simple punch attack animation"""
	if not animation_player:
		print("❌ Ally: No animation player for attack animation")
		return
	
	# Refresh hand reference in case it wasn't set yet
	if not right_hand:
		right_hand = get_node_or_null("RightHandAnchor/RightHand")
	
	if not right_hand:
		print("❌ Ally: No right hand found for attack animation")
		return
	
	var animation = Animation.new()
	animation.length = 0.4
	
	# Create punch track - use right hand like player does
	var punch_track = animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(punch_track, NodePath("RightHandAnchor/RightHand"))
	
	# Punch positions (forward punch like player)
	var start_pos = Vector3(0.0, 0.0, 0.0)
	var punch_pos = Vector3(0.0, 0.05, 0.6)  # Forward punch like player
	var end_pos = start_pos
	
	animation.track_insert_key(punch_track, 0.0, start_pos)
	animation.track_insert_key(punch_track, 0.2, punch_pos)
	animation.track_insert_key(punch_track, 0.4, end_pos)
	
	# Add animation to library
	var library = AnimationLibrary.new()
	library.add_animation("attack", animation)
	animation_player.add_animation_library("default", library)
	
	# Connect animation finished signal
	if not animation_player.animation_finished.is_connected(_on_attack_animation_finished):
		animation_player.animation_finished.connect(_on_attack_animation_finished)
	
	print("✅ Ally: Attack animation created successfully")

func _create_fallback_punch():
	"""Create a simple punch effect without animation player"""
	# Refresh hand reference in case it wasn't set yet
	if not right_hand:
		right_hand = get_node_or_null("RightHandAnchor/RightHand")
	
	if not right_hand:
		print("❌ Ally: No right hand for fallback punch")
		return
	
	print("🥊 Ally: Using fallback punch animation")
	# Store original position
	var original_pos = right_hand.position
	# Create manual punch animation with Tween
	var tween = create_tween()
	tween.set_parallel(true)
	# Punch forward
	tween.tween_property(right_hand, "position", original_pos + Vector3(0, 0.05, 0.6), 0.2)
	# Return to original position
	tween.tween_property(right_hand, "position", original_pos, 0.2).set_delay(0.2)
	# Mark attack as finished after animation
	tween.tween_callback(func(): is_attacking = false).set_delay(0.4)

func _setup_combat_system():
	"""Setup combat detection and damage systems"""
	# We'll use the existing enemy detection from _find_nearest_enemy()
	print("✅ Ally: Combat system ready")

func _physics_process(delta):
	"""Main update loop"""
	if current_health <= 0:
		return
	
	attack_timer = max(0, attack_timer - delta)
	
	_update_ai_state()
	_handle_movement(delta)
	_handle_combat(delta)
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	move_and_slide()

func _update_ai_state():
	"""Update AI state based on conditions"""
	if is_attacking:
		current_state = AllyState.ATTACKING
		return
	
	# Find nearest enemy
	current_target = _find_nearest_enemy()
	
	if current_target and global_position.distance_to(current_target.global_position) <= attack_range:
		current_state = AllyState.ATTACKING
	elif current_target and global_position.distance_to(current_target.global_position) <= detection_range:
		current_state = AllyState.MOVING_TO_TARGET
	else:
		current_state = AllyState.FOLLOWING

func _handle_movement(delta):
	"""Handle movement based on current state"""
	match current_state:
		AllyState.FOLLOWING:
			_follow_player(delta)
		AllyState.MOVING_TO_TARGET:
			_move_to_target(delta)
		AllyState.ATTACKING:
			_combat_movement(delta)

func _follow_player(delta):
	"""Intelligent player following with orbiting behavior"""
	if not player:
		return
	
	# Calculate orbit position around player
	orbit_angle += orbit_speed * delta
	if orbit_angle > TAU:
		orbit_angle -= TAU
	
	var orbit_pos = player.global_position + Vector3(
		cos(orbit_angle) * orbit_radius,
		0,
		sin(orbit_angle) * orbit_radius
	)
	
	# Add some randomness to make movement more natural
	orbit_pos += Vector3(
		sin(Time.get_ticks_msec() * 0.001) * 0.5,
		0,
		cos(Time.get_ticks_msec() * 0.0007) * 0.5
	)
	
	# Move toward orbit position
	var direction = (orbit_pos - global_position)
	direction.y = 0
	
	if direction.length() > 1.0:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Face movement direction
		_face_direction(direction)
	else:
		velocity.x = lerp(velocity.x, 0.0, 0.1)
		velocity.z = lerp(velocity.z, 0.0, 0.1)

func _move_to_target(delta):
	"""Move toward current enemy target"""
	if not current_target:
		_follow_player(delta)
		return
	
	var direction = (current_target.global_position - global_position)
	direction.y = 0
	
	var distance = direction.length()
	if distance > attack_range:
		direction = direction.normalized()
		velocity.x = direction.x * speed * 1.2  # Move faster when attacking
		velocity.z = direction.z * speed * 1.2
		
		_face_direction(direction)
	else:
		velocity.x = lerp(velocity.x, 0.0, 0.3)
		velocity.z = lerp(velocity.z, 0.0, 0.3)

func _combat_movement(_delta):
	"""Movement during combat (minimal)"""
	velocity.x = lerp(velocity.x, 0.0, 0.2)
	velocity.z = lerp(velocity.z, 0.0, 0.2)
	
	# Face the enemy
	if current_target:
		var direction = (current_target.global_position - global_position)
		direction.y = 0
		if direction.length() > 0.1:
			_face_direction(direction.normalized())

func _handle_combat(_delta):
	"""Handle combat logic"""
	if not current_target or attack_timer > 0 or is_attacking:
		return
	
	var distance = global_position.distance_to(current_target.global_position)
	if distance <= attack_range:
		_start_attack()

func _start_attack():
	"""Begin attack sequence"""
	if is_attacking or attack_timer > 0:
		return
	
	is_attacking = true
	attack_timer = attack_cooldown
	
	# Debug attack system
	print("🥊 Ally starting attack - Animation player exists: ", animation_player != null)
	if animation_player:
		print("🥊 Has attack animation: ", animation_player.has_animation("attack"))
		print("🥊 Animation libraries: ", animation_player.get_animation_library_list())
	
	# Play attack animation or fallback
	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")
	else:
		print("🥊 Ally: Animation not available, using fallback")
		_create_fallback_punch()
	
	# Deal damage after slight delay
	get_tree().create_timer(0.2).timeout.connect(_deal_damage)
	
	var target_name = "unknown"
	if current_target and "name" in current_target:
		target_name = str(current_target.name)
	print("🗡️ Ally: Starting attack on ", target_name)

func _deal_damage():
	"""Deal damage to current target"""
	if not current_target or not is_instance_valid(current_target):
		return
	
	# Check if still in range
	var distance = global_position.distance_to(current_target.global_position)
	if distance > attack_range * 1.2:
		return
	
	# Deal damage
	if current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)
		print("🗡️ Ally dealt ", attack_damage, " damage to ", current_target.name)
	
	# Show damage numbers
	var damage_system = get_tree().get_first_node_in_group("damage_numbers")
	if damage_system:
		damage_system.show_damage(attack_damage, current_target, "normal")

func _on_attack_animation_finished(anim_name: StringName):
	"""Called when attack animation finishes"""
	if anim_name == "attack":
		is_attacking = false

func _face_direction(direction: Vector3):
	"""Face a specific direction smoothly"""
	if direction.length() < 0.1:
		return
	
	# Fix: Face the enemy (not backwards)
	var target_rotation = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, 0.1)
	last_facing_direction = direction

func _find_nearest_enemy() -> Node3D:
	"""Find the nearest enemy within detection range"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_enemy: Node3D = null
	var nearest_distance := 999.0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance and distance <= detection_range:
			nearest_distance = distance
			nearest_enemy = enemy
	
	return nearest_enemy

func take_damage(amount: int, _attacker: Node = null):
	"""Handle taking damage"""
	if current_health <= 0:
		return
	
	current_health -= amount
	print("🤝 Ally took ", amount, " damage! Health: ", current_health, "/", max_health)
	
	# Show damage numbers
	var damage_system = get_tree().get_first_node_in_group("damage_numbers")
	if damage_system:
		damage_system.show_damage(amount, self, "normal")
	
	# Flash red briefly
	if mesh_instance and mesh_instance.material_override:
		var original_color = mesh_instance.material_override.albedo_color
		mesh_instance.material_override.albedo_color = Color.RED
		get_tree().create_timer(0.1).timeout.connect(
			func(): 
				if is_instance_valid(mesh_instance) and mesh_instance.material_override:
					mesh_instance.material_override.albedo_color = original_color
		)
	
	if current_health <= 0:
		die()

func die():
	"""Handle ally death"""
	print("💀 Ally died!")
	current_state = AllyState.DEAD
	
	# Emit death signal
	emit_signal("ally_died")
	
	# Create death effect
	if mesh_instance:
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", Vector3.ZERO, 0.5)
		await tween.finished
	
	queue_free()

func get_ally_stats() -> Dictionary:
	"""Get current ally statistics"""
	var target_name = "None"
	if current_target and "name" in current_target:
		target_name = str(current_target.name)
	return {
		"health": current_health,
		"max_health": max_health,
		"attack_damage": attack_damage,
		"state": AllyState.keys()[current_state],
		"target": target_name
	}
