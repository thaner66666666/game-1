# CharacterAppearanceManager.gd - FIXED VERSION
class_name CharacterAppearanceManager
extends Node

# Godot 3D coordinate system:
#   X+: right, X-: left
#   Y+: up,    Y-: down
#   Z+: back,  Z-: forward (out of face)
#   (0,0,0) is character center

# Color constants
static var SKIN_COLOR = Color(0.9, 0.7, 0.6)
static var EYE_COLOR = Color.BLACK

# Eye constants
static var EYE_POSITION_HEIGHT: float = 0.3  # Height offset from body center
static var EYE_SPACING: float = 0.2  # Distance between eyes
static var PUPIL_SIZE: float = 0.6  # Pupil size relative to eye

# Cached materials
static var SKIN_MATERIAL: StandardMaterial3D = null
static var EYE_MATERIAL: StandardMaterial3D = null

# Static tweakable constants
static var BODY_HEIGHT: float = 1.5
static var BODY_RADIUS: float = 0.3
static var EYE_SIZE: float = 0.07  # was 0.09, now slightly smaller
static var HAND_SIZE: float = 0.08
static var FOOT_SIZE: Vector3 = Vector3(0.15, 0.06, 0.25)

static func _init_materials():
	if SKIN_MATERIAL == null:
		SKIN_MATERIAL = StandardMaterial3D.new()
		SKIN_MATERIAL.albedo_color = SKIN_COLOR
		SKIN_MATERIAL.metallic = 0.0
		SKIN_MATERIAL.roughness = 0.7
		SKIN_MATERIAL.clearcoat = 0.1
		SKIN_MATERIAL.rim = 0.3
		SKIN_MATERIAL.rim_tint = 0.5
	if EYE_MATERIAL == null:
		EYE_MATERIAL = StandardMaterial3D.new()
		EYE_MATERIAL.albedo_color = EYE_COLOR
		EYE_MATERIAL.metallic = 0.8
		EYE_MATERIAL.roughness = 0.1

static func create_player_appearance(character: CharacterBody3D, config := {}):
	"""Create Rayman-style character with modular features based on config"""
	print("🎨 Creating Rayman-style character...")

	_init_materials()
	_clear_existing_appearance(character)

	# Update skin material if custom skin tone provided
	if config.has("skin_tone"):
		var custom_skin = SKIN_MATERIAL.duplicate()
		custom_skin.albedo_color = config["skin_tone"]
		SKIN_MATERIAL = custom_skin

	# Enhanced body creation with config
	var body_type = config.get("body_type", "capsule")
	var body_height = config.get("body_height", BODY_HEIGHT)
	var body_radius = config.get("body_radius", BODY_RADIUS)
	var main_mesh = character.get_node("MeshInstance3D")
	_create_simple_body(main_mesh, body_type, body_height, body_radius)

	# EYES - pass body_radius to eyes (from config, not from eyes_cfg)
	var eyes_cfg = config.get("eyes", {})
	_create_eyes(character, eyes_cfg, main_mesh, body_radius)

	# HANDS
	var hands_cfg = config.get("hands", {})
	_create_hands(character, hands_cfg)

	# FEET
	var feet_cfg = config.get("feet", {})
	_create_feet(character, feet_cfg)

	print("✅ Rayman-style character created!")
	return main_mesh

# FIXED: Added the missing create_random_character function
static func create_random_character(character: CharacterBody3D):
	"""Create a completely random character using CharacterGenerator"""
	var config = CharacterGenerator.generate_random_character_config()
	return create_player_appearance(character, config)

static func _clear_existing_appearance(character: CharacterBody3D):
	"""Clear any existing parts - FIXED with more comprehensive clearing"""
	var parts_to_remove = [
		"LeftArm", "RightArm", "LeftLeg", "RightLeg",
		"LeftHand", "RightHand", "LeftFoot", "RightFoot", "Foot0", "Foot1",
		"LeftEye", "RightEye",  # Added eyes
		"Hair", "Mustache", "Goatee", "Beard"
	]
	
	# Also clear any numbered hair parts (for curly/spiky styles)
	for i in range(20):
		parts_to_remove.append("HairPart" + str(i))
		parts_to_remove.append("Curl" + str(i))
		parts_to_remove.append("Spike" + str(i))
	
	for part_name in parts_to_remove:
		var part = character.get_node_or_null(part_name)
		if part:
			part.queue_free()

static func _create_simple_body(mesh_instance: MeshInstance3D, body_type: String, height: float, radius: float):
	"""Capsule or rounded box body"""
	if body_type == "box":
		var box = BoxMesh.new()
		box.size = Vector3(radius * 2, height, radius * 2)
		mesh_instance.mesh = box
		mesh_instance.position = Vector3(0, 0, 0)
	else:
		var capsule_mesh = CapsuleMesh.new()
		capsule_mesh.radius = radius
		capsule_mesh.height = height
		mesh_instance.mesh = capsule_mesh
		mesh_instance.position = Vector3(0, 0, 0)
	mesh_instance.material_override = SKIN_MATERIAL

static func _create_hands(character: CharacterBody3D, cfg := {}):
	"""Floating hands with shape and position options"""
	var _shape = cfg.get("shape", "fist")
	var size = cfg.get("size", HAND_SIZE)
	var _dist = cfg.get("distance", 0.44)
	var _height = cfg.get("height", -0.20)
	
	for i in [-1, 1]:
		var hand = MeshInstance3D.new()
		hand.name = "LeftHand" if i < 0 else "RightHand"
		var mesh = BoxMesh.new()
		mesh.size = Vector3(size * 2.5, size * 1.5, size * 2.5)
		hand.mesh = mesh
		hand.position = Vector3(i * _dist, _height, 0)
		hand.rotation_degrees = Vector3(0, 0, 90)
		hand.material_override = SKIN_MATERIAL
		character.add_child(hand)

static func _create_feet(character: CharacterBody3D, cfg := {}):
	"""Floating feet with shape and position options.
	All foot shapes use BoxMesh for safety and appropriateness."""
	var shape = cfg.get("shape", "bare")
	var size = cfg.get("size", FOOT_SIZE)
	var dist = cfg.get("distance", 0.25)
	var height = cfg.get("height", -1.05) + 0.2 - 0.05
	var scale_vec = Vector3(0.85 * 0.75, 0.85, 0.85)

	# Only BoxMesh is allowed for all foot shapes for safety and style consistency.
	for i in [-1, 1]:
		var foot = MeshInstance3D.new()
		foot.name = "LeftFoot" if i < 0 else "RightFoot"
		var mesh = BoxMesh.new()
		match shape:
			"bare":
				mesh.size = Vector3(size.x * 1.7, size.y * 2.5, size.z * 1.7)
				foot.scale = scale_vec
			"boot":
				mesh.size = Vector3(size.x * 1.8, size.y * 2.5, size.z * 1.9)
				foot.scale = scale_vec
			"small":
				mesh.size = Vector3(size.x * 1.2, size.y * 2.2, size.z * 1.2)
				foot.scale = scale_vec
			"wide":
				mesh.size = Vector3(size.x * 2.2, size.y * 2.5, size.z * 2.2)
				foot.scale = scale_vec
			_:
				mesh.size = Vector3(size.x * 1.2, size.y * 2.2, size.z * 1.2)
				foot.scale = scale_vec
		foot.mesh = mesh
		foot.position = Vector3(i * dist, height, 0)
		foot.material_override = SKIN_MATERIAL
		character.add_child(foot)

static func get_eye_z_position(body_radius: float) -> float:
	# For skinny (radius ~0.15): Z = -0.15 (closer to center)
	# For wide (radius ~0.4): Z = -0.4 (further out)
	# Linear interpolation between -0.15 and -0.4
	var min_radius = 0.15
	var max_radius = 0.4
	var min_z = -0.15
	var max_z = -0.4
	var t = clamp((body_radius - min_radius) / (max_radius - min_radius), 0, 1)
	return lerp(min_z, max_z, t)

static func _create_eyes(_character: CharacterBody3D, cfg := {}, mesh_instance: MeshInstance3D = null, body_radius: float = BODY_RADIUS):
	"""Create expressive floating eyes with pupils, using body_radius for Z offset"""
	if not mesh_instance:
		print("⚠️ No mesh_instance provided, eyes might not animate properly")
		return

	var eye_color = cfg.get("color", Color.WHITE)
	var eye_size = cfg.get("size", EYE_SIZE)
	var eye_spacing = cfg.get("spacing", EYE_SPACING)
	var pupil_color = cfg.get("pupil_color", Color.BLACK)
	var eye_height = cfg.get("height", EYE_POSITION_HEIGHT)

	# Calculate Z position for eyes based on body_radius
	var base_z_offset = -0.15
	var adjustment_factor = -0.625  # (so at radius=0.4: -0.15 + 0.4*-0.625 = -0.4)
	var eye_z = base_z_offset + (body_radius * adjustment_factor)

	# Create eye materials
	var eye_material = StandardMaterial3D.new()
	eye_material.albedo_color = eye_color
	eye_material.metallic = 0.1
	eye_material.roughness = 0.3
	eye_material.clearcoat = 0.8
	eye_material.clearcoat_roughness = 0.1
	
	var pupil_material = StandardMaterial3D.new()
	pupil_material.albedo_color = pupil_color
	pupil_material.metallic = 0.9
	pupil_material.roughness = 0.1
	pupil_material.emission_enabled = true
	pupil_material.emission = Color(0.1, 0.1, 0.2) * 0.3
	
	# Create eyes
	for i in [-1, 1]:  # Left and right
		var eye_container = Node3D.new()
		eye_container.name = "LeftEye" if i < 0 else "RightEye"
		mesh_instance.add_child(eye_container)  # Attach to mesh instead of character
		
		# Position the eye container
		eye_container.position = Vector3(i * eye_spacing / 2, eye_height, eye_z)  # Use dynamic Z
		
		# Create eyeball
		var eyeball = MeshInstance3D.new()
		eyeball.name = "Eyeball"
		var eye_sphere = SphereMesh.new()
		eye_sphere.radius = eye_size
		eye_sphere.height = eye_size * 2
		eyeball.mesh = eye_sphere
		eyeball.material_override = eye_material
		eye_container.add_child(eyeball)
		
		# Create pupil
		var pupil = MeshInstance3D.new()
		pupil.name = "Pupil"
		var pupil_sphere = SphereMesh.new()
		pupil_sphere.radius = eye_size * PUPIL_SIZE
		pupil_sphere.height = eye_size * PUPIL_SIZE * 2
		pupil.mesh = pupil_sphere
		pupil.material_override = pupil_material
		pupil.position = Vector3(0, 0, eye_size * 0.3)  # Slightly forward
		eyeball.add_child(pupil)
		
		# Add highlight for more life
		var highlight = MeshInstance3D.new()
		highlight.name = "Highlight"
		var highlight_sphere = SphereMesh.new()
		highlight_sphere.radius = eye_size * 0.2
		highlight_sphere.height = eye_size * 0.2 * 2
		highlight.mesh = highlight_sphere
		
		var highlight_material = StandardMaterial3D.new()
		highlight_material.albedo_color = Color.WHITE
		highlight_material.emission_enabled = true
		highlight_material.emission = Color.WHITE * 0.8
		highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		highlight_material.albedo_color.a = 0.9
		highlight.material_override = highlight_material
		
		highlight.position = Vector3(eye_size * 0.15, eye_size * 0.15, eye_size * 0.4)
		eyeball.add_child(highlight)

static func animate_eyes_look_at(character: CharacterBody3D, target_position: Vector3):
	"""Make eyes look at a target position"""
	var mesh_instance = character.get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return
		
	var left_eye = mesh_instance.get_node_or_null("LeftEye")
	var right_eye = mesh_instance.get_node_or_null("RightEye")
	
	if not left_eye or not right_eye:
		return
	
	for eye in [left_eye, right_eye]:
		var eyeball = eye.get_node_or_null("Eyeball")
		if not eyeball:
			continue
		
		var eye_global_pos = eye.global_position
		var direction = (target_position - eye_global_pos).normalized()
		
		# Limit eye movement range
		var max_angle = deg_to_rad(30)  # Eyes can look 30 degrees in any direction
		var forward = Vector3(0, 0, 1)
		var angle = forward.angle_to(direction)
		
		if angle > max_angle:
			direction = forward.slerp(direction, max_angle / angle)
		
		# Apply rotation to eyeball
		eyeball.look_at(eye_global_pos + direction, Vector3.UP)

static func blink_eyes(character: CharacterBody3D, blink_duration: float = 0.15):
	"""Create a blinking animation"""
	var mesh_instance = character.get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return
		
	var left_eye = mesh_instance.get_node_or_null("LeftEye/Eyeball")
	var right_eye = mesh_instance.get_node_or_null("RightEye/Eyeball")
	
	if not left_eye or not right_eye:
		return
	
	var original_scale = Vector3.ONE
	var blink_scale = Vector3(1.0, 0.1, 1.0)  # Flatten Y axis for blink
	
	# Create blink animation
	var tween = character.create_tween()
	tween.set_parallel(true)
	
	# Close eyes
	tween.tween_property(left_eye, "scale", blink_scale, blink_duration / 2)
	tween.tween_property(right_eye, "scale", blink_scale, blink_duration / 2)
	
	# Open eyes
	tween.tween_property(left_eye, "scale", original_scale, blink_duration / 2).set_delay(blink_duration / 2)
	tween.tween_property(right_eye, "scale", original_scale, blink_duration / 2).set_delay(blink_duration / 2)

# Add this helper for foot animation (call from player.gd _update_walking_hand_animation)
static func animate_feet_walk(left_foot: MeshInstance3D, right_foot: MeshInstance3D, left_foot_origin: Vector3, right_foot_origin: Vector3, anim_time: float, velocity: Vector3, delta: float):
	if not left_foot or not right_foot:
		return
	var speed = velocity.length()
	if speed < 0.05:
		# Snap to original position if not moving
		left_foot.position = left_foot_origin
		right_foot.position = right_foot_origin
		return

	# Shuffle: small, quick steps
	var walk_cycle_speed = clamp(speed * 4.0, 6.0, 12.0)
	var stride = 0.04  # Small stride for shuffle
	var lift = 0.01    # Very little lift for shuffle
	var phase = anim_time * walk_cycle_speed

	# Left foot
	var left_offset_z = sin(phase) * stride
	var left_offset_y = abs(sin(phase)) * lift
	var left_target = left_foot_origin + Vector3(0, left_offset_y, left_offset_z)
	# Right foot (opposite phase)
	var right_offset_z = sin(phase + PI) * stride
	var right_offset_y = abs(sin(phase + PI)) * lift
	var right_target = right_foot_origin + Vector3(0, right_offset_y, right_offset_z)

	var interp_speed = clamp(delta * 16.0, 0.0, 1.0)
	left_foot.position = left_foot.position.lerp(left_target, interp_speed)
	right_foot.position = right_foot.position.lerp(right_target, interp_speed)
