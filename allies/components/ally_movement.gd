extends Node
class_name AllyMovement

# Handles movement for the ally

var ally_ref
var speed: float
var follow_distance := 4.0
var separation_distance := 1.5
var orbit_radius := 2.5
var orbit_angle: float

func setup(ally, move_speed: float):
	ally_ref = ally
	speed = move_speed
	orbit_angle = randf() * TAU  # Random starting orbit position

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

func orbit_around_player(player: Node3D, delta: float):
	if not player:
		return
	
	# Update orbit angle
	orbit_angle += delta * 0.8
	if orbit_angle > TAU:
		orbit_angle -= TAU
	
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
			var force_strength = (separation_distance - distance) / separation_distance
			separation_force += away_dir * force_strength * 2.0
	
	# Apply separation to velocity
	ally_ref.velocity.x += separation_force.x * speed * delta
	ally_ref.velocity.z += separation_force.z * speed * delta

func _face_direction(direction: Vector3):
	if direction.length() < 0.1:
		return
	
	var target_rotation = atan2(-direction.x, -direction.z)
	ally_ref.rotation.y = lerp_angle(ally_ref.rotation.y, target_rotation, 0.1)
