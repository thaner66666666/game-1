extends Node
class_name AllyMovement

# Handles movement for the ally

var ally_ref
var speed: float
var follow_distance := 4.0
var separation_distance := 1.5
var orbit_radius := 2.5
var orbit_angle: float

# Foot animation variables
var walk_cycle_time := 0.0
var step_cycle_speed := 1.0
var personality_offset := 0.0

# Animation parameters
var foot_step_strength := 0.18
var side_step_modifier := 1.4

# Signal for foot animation updates
signal foot_animation_update(left_pos: Vector3, right_pos: Vector3)

# Animation node references
var left_foot_node: Node3D = null
var right_foot_node: Node3D = null
var left_foot_origin: Vector3 = Vector3.ZERO
var right_foot_origin: Vector3 = Vector3.ZERO

func setup(ally, move_speed: float):
	ally_ref = ally
	speed = move_speed
	orbit_angle = randf() * TAU  # Random starting orbit position
	# Wait one frame to ensure ally is fully instantiated
	await ally.get_tree().process_frame
	initialize_foot_animation()
	# Validate initialization
	if not left_foot_node or not right_foot_node:
		print("⚠️ ALLY FOOT SETUP FAILED: Could not find foot nodes!")
	else:
		print("✅ ALLY FOOT SETUP SUCCESS: Foot nodes found and stored")

func move_towards_target(target_pos: Vector3, delta: float):
	var direction = (target_pos - ally_ref.global_position)
	direction.y = 0  # Keep on ground
	
	if direction.length() > 0.1:
		direction = direction.normalized()
		ally_ref.velocity.x = direction.x * speed
		ally_ref.velocity.z = direction.z * speed
		_face_direction(direction)
	else:
		# Stop when close enough
		ally_ref.velocity.x = move_toward(ally_ref.velocity.x, 0, speed * 2 * delta)
		ally_ref.velocity.z = move_toward(ally_ref.velocity.z, 0, speed * 2 * delta)
	# Update foot animation
	var is_moving = true  # Force for testing
	_update_foot_animation(delta, is_moving)
	print("🚶 move_towards_target called, velocity=", ally_ref.velocity.length())

func orbit_around_player(player: Node3D, delta: float):
	if not player:
		return
	
	# Update orbit angle
	orbit_angle += delta * 0.8
	if orbit_angle > TAU:
		orbit_angle -= TAU
	
	# --- Avoidance buffer: adjust orbit_angle if allies are too close ---
	var avoidance_radius = 2.0
	var angle_adjust = 0.0
	var allies = get_tree().get_nodes_in_group("allies")
	for other_ally in allies:
		if other_ally == ally_ref or not is_instance_valid(other_ally):
			continue
		var dist = ally_ref.global_position.distance_to(other_ally.global_position)
		if dist < avoidance_radius:
			# Try to find clear space by nudging angle
			if angle_adjust == 0.0:
				angle_adjust = 0.5 if randi() % 2 == 0 else -0.5
	if angle_adjust != 0.0:
		orbit_angle += angle_adjust
	
	# Calculate orbit position
	var orbit_offset = Vector3(
		cos(orbit_angle) * orbit_radius,
		0,
		sin(orbit_angle) * orbit_radius
	)
	var target_pos = player.global_position + orbit_offset
	
	# Move towards orbit position
	var distance_to_player = ally_ref.global_position.distance_to(player.global_position)
	if distance_to_player > follow_distance:
		move_towards_target(target_pos, delta)
	else:
		# Update foot animation even when orbiting - check velocity!
		var is_moving = true  # Force for testing
		_update_foot_animation(delta, is_moving)

func apply_separation(delta: float):
	var allies = get_tree().get_nodes_in_group("allies")
	var separation_force = Vector3.ZERO
	
	for other_ally in allies:
		if other_ally == ally_ref or not is_instance_valid(other_ally):
			continue
		
		var distance = ally_ref.global_position.distance_to(other_ally.global_position)
		if distance < separation_distance and distance > 0:
			var away_dir = (ally_ref.global_position - other_ally.global_position).normalized()
			away_dir.y = 0
			# Exponential falloff for stronger repulsion
			var force_strength = pow((separation_distance - distance) / separation_distance, 2) * 3.0
			separation_force += away_dir * force_strength
	
	# Apply separation to velocity
	ally_ref.velocity.x += separation_force.x * speed * delta
	ally_ref.velocity.z += separation_force.z * speed * delta

func _face_direction(direction: Vector3):
	if direction.length() < 0.1:
		return
	
	var target_rotation = atan2(-direction.x, -direction.z)
	ally_ref.rotation.y = lerp_angle(ally_ref.rotation.y, target_rotation, 0.1)

func initialize_foot_animation():
	print("🦶 SEARCH: Looking for foot nodes...")
	left_foot_node = ally_ref.get_node_or_null("LeftFoot")
	right_foot_node = ally_ref.get_node_or_null("RightFoot")
	print("🦶 LEFT: ", left_foot_node)
	print("🦶 RIGHT: ", right_foot_node)
	# Store original positions
	if left_foot_node:
		left_foot_origin = left_foot_node.position
	if right_foot_node:
		right_foot_origin = right_foot_node.position
	print("🦶 Ally foot animation initialized - Origins: [", left_foot_origin, ", ", right_foot_origin, "]")

func _update_foot_animation(delta: float, is_moving: bool):
	# Use stored references instead of searching each time
	if not left_foot_node or not right_foot_node:
		print("🦶 MISSING: Foot node references not initialized!")
		return
	# Validate that the nodes are still valid
	if not is_instance_valid(left_foot_node) or not is_instance_valid(right_foot_node):
		print("🦶 INVALID: Foot nodes became invalid!")
		return
	if not is_moving:
		# Return to rest position when not moving
		left_foot_node.position = left_foot_origin
		right_foot_node.position = right_foot_origin
		return
	# Advance walk cycle
	var move_speed = ally_ref.velocity.length()
	step_cycle_speed = max(4.0, move_speed / max(1.0, speed) * 5.0)
	walk_cycle_time += delta * step_cycle_speed * 2.0
	# Keep in range [0, TAU]
	if walk_cycle_time > TAU:
		walk_cycle_time -= TAU
	# Calculate foot animation phases
	var foot_phase = walk_cycle_time + personality_offset
	# Calculate foot movements
	var foot_swing_modifier = foot_step_strength
	var left_foot_swing = sin(foot_phase) * foot_swing_modifier
	var right_foot_swing = sin(foot_phase + PI) * foot_swing_modifier
	var left_foot_lift = max(0, sin(foot_phase + PI/2)) * 0.12
	var right_foot_lift = max(0, sin(foot_phase + PI + PI/2)) * 0.12
	# Apply foot positions
	var left_foot_pos = left_foot_origin + Vector3(0, left_foot_lift, left_foot_swing)
	var right_foot_pos = right_foot_origin + Vector3(0, right_foot_lift, right_foot_swing)
	# ACTUALLY MOVE THE FOOT NODES!
	left_foot_node.position = left_foot_pos
	right_foot_node.position = right_foot_pos
	# Emit signal for any listeners
	foot_animation_update.emit(left_foot_pos, right_foot_pos)
	print("🦶 SUCCESS: Animated feet - Left: ", left_foot_pos, " Right: ", right_foot_pos)
