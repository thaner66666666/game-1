extends Node
class_name AllyMovement

# Handles movement for the ally

var ally_ref
var speed: float
var follow_distance := 4.0
var separation_distance := 1.5
var orbit_radius := 2.5
var orbit_angle: float

# Body animation variables
var body_origin: Vector3
var current_body_sway: Vector3 = Vector3.ZERO
var target_body_sway: Vector3 = Vector3.ZERO
var body_sway_strength: float = 0.03  # Very subtle sway
var body_lean_strength: float = 0.07  # Very subtle leaning
var interpolation_speed: float = 8.0  # Smoother animation transitions
var walk_cycle_time: float = 0.0
var personality_offset: float = 0.0
var body_node

func setup(ally, move_speed: float):
	ally_ref = ally
	speed = move_speed
	orbit_angle = randf() * TAU  # Random starting orbit position
	initialize_body_animation()

func initialize_body_animation():
	# Find the body node (MeshInstance3D with 'Body', 'Torso', or 'Chest' in name)
	body_node = null
	var mesh_children = []
	for child in ally_ref.get_children():
		if child is MeshInstance3D:
			mesh_children.append(child)
	# Use 'body_name' to avoid shadowing base class property
	for body_name in ["Body", "Torso", "Chest"]:
		for child in mesh_children:
			if body_name in child.name:
				body_node = child
				break
		if body_node:
			break
	if not body_node and ally_ref.mesh_instance:
		body_node = ally_ref.mesh_instance
	if body_node:
		body_origin = body_node.position
	else:
		body_origin = Vector3.ZERO
	personality_offset = randf_range(-0.1, 0.1)
	current_body_sway = Vector3.ZERO
	target_body_sway = Vector3.ZERO

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
	
	# Call body animation update after velocity is set
	if body_node:
		_update_ally_body_animation(delta, ally_ref.velocity)

func _update_ally_body_animation(delta: float, velocity: Vector3):
	if not body_node:
		return
	if velocity.length() > 0.1:
		walk_cycle_time += delta * 5.0
		var vel_scale = clamp(velocity.length() / 3.5, 0.3, 1.0)
		var vertical_bob = sin(walk_cycle_time * 2.0 + personality_offset) * 0.07 * vel_scale  # Very subtle bobbing
		var horizontal_sway = sin(walk_cycle_time + personality_offset) * 0.02 * vel_scale  # Very subtle sway
		var wiggle = sin(walk_cycle_time * 2.0 + personality_offset) * 0.02 * vel_scale  # Minimal wiggle
		target_body_sway = Vector3(horizontal_sway, vertical_bob, wiggle)
		current_body_sway = lerp(current_body_sway, target_body_sway, interpolation_speed * delta)
		body_node.position = body_origin + current_body_sway
		#print("[AllyBodyAnim] vel:", velocity.length(), "sway:", current_body_sway)
	else:
		walk_cycle_time = 0.0
		current_body_sway = lerp(current_body_sway, Vector3.ZERO, interpolation_speed * delta)
		body_node.position = body_origin + current_body_sway

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


# ...existing code...
func strafe_around_target(target: Node3D, delta: float):
	if not target:
		return
	# Calculate direction to enemy and perpendicular strafe direction
	var to_enemy = (target.global_position - ally_ref.global_position)
	to_enemy.y = 0
	if to_enemy.length() < 0.1:
		return
	to_enemy = to_enemy.normalized()
	var strafe_dir = Vector3(-to_enemy.z, 0, to_enemy.x)  # Perpendicular
	# Mix forward and strafe for circling
	var move_dir = (to_enemy + strafe_dir * (randf() * 1.2 - 0.6)).normalized()
	ally_ref.velocity.x = move_dir.x * speed
	ally_ref.velocity.z = move_dir.z * speed
	_face_direction(to_enemy)
	if body_node:
		_update_ally_body_animation(delta, ally_ref.velocity)
# ...existing code...
func move_away_from_target(target_pos: Vector3, delta: float):
	var direction = (ally_ref.global_position - target_pos)
	direction.y = 0
	if direction.length() > 0.1:
		direction = direction.normalized()
		ally_ref.velocity.x = direction.x * speed
		ally_ref.velocity.z = direction.z * speed
		_face_direction(-direction)
	if body_node:
		_update_ally_body_animation(delta, ally_ref.velocity)
# ...existing code...
