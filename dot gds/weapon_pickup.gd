# weapon_pickup.gd - Enhanced weapon pickup with better visuals
extends Area3D

# Weapon resource assigned to this pickup
@export var weapon_resource: WeaponResource = null

# Enhanced visual settings
@export var glow_intensity: float = 1.5
@export var rotation_speed: float = 30.0
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.0

# References to scene nodes
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Floating text and interaction
var floating_text: Label3D = null
var player_in_range: bool = false
var player: Node3D = null
var weapon_material: StandardMaterial3D
var time_alive: float = 0.0

# For composite weapons (multiple mesh parts)
var weapon_parts: Array[MeshInstance3D] = []

func _ready():
	print("🗡️ Enhanced Weapon Pickup: Setting up...")
	add_to_group("weapon_pickup")
	collision_layer = 4
	collision_mask = 1
	
	# Set pickup disabled initially if this came from physics
	if get_meta("from_physics", false):
		set_meta("pickup_disabled", true)
		_create_pickup_delay_effect(0.2)
	
	_find_player()
	_create_floating_text()
	# Only setup visual if weapon_resource is already set
	if weapon_resource:
		_setup_enhanced_visual()

func _setup_enhanced_visual():
	"""Create enhanced weapon pickup visual"""
	# FIRST: Clear the original mesh to get rid of the white ball
	if mesh_instance:
		mesh_instance.mesh = null
		mesh_instance.material_override = null
	
	if not weapon_resource:
		_create_default_visual()
		return
	
	# Clear any existing parts
	_clear_weapon_parts()
	
	# Create weapon-specific enhanced visual
	match weapon_resource.weapon_type:
		WeaponResource.WeaponType.SWORD:
			_create_enhanced_sword()
		WeaponResource.WeaponType.BOW:
			_create_enhanced_bow()
		WeaponResource.WeaponType.STAFF:
			_create_enhanced_staff()
		_:
			_create_default_visual()
	
	# Create collision shape
	var collision = SphereShape3D.new()
	collision.radius = 0.8
	collision_shape.shape = collision

func _clear_weapon_parts():
	"""Clear existing weapon parts"""
	for part in weapon_parts:
		if is_instance_valid(part) and part != mesh_instance:  # Don't delete the scene's original mesh_instance
			part.queue_free()
	weapon_parts.clear()
	
	# Clear the original mesh_instance content but keep the node
	if mesh_instance:
		mesh_instance.mesh = null
		mesh_instance.material_override = null

func _create_enhanced_sword():
	"""Create detailed sword pickup visual"""
	# Main blade
	var blade = MeshInstance3D.new()
	var blade_mesh = BoxMesh.new()
	blade_mesh.size = Vector3(0.08, 1.0, 0.15)
	blade.mesh = blade_mesh
	blade.position = Vector3(0, 0.1, 0)
	
	# Enhanced blade material
	var blade_material = StandardMaterial3D.new()
	blade_material.albedo_color = Color(0.9, 0.9, 1.0)
	blade_material.metallic = 0.95
	blade_material.roughness = 0.1
	blade_material.emission_enabled = true
	blade_material.emission = Color(0.8, 0.9, 1.0) * glow_intensity * 0.3
	blade.material_override = blade_material
	
	add_child(blade)
	weapon_parts.append(blade)
	
	# Crossguard
	var crossguard = MeshInstance3D.new()
	var guard_mesh = BoxMesh.new()
	guard_mesh.size = Vector3(0.4, 0.05, 0.12)
	crossguard.mesh = guard_mesh
	crossguard.position = Vector3(0, -0.35, 0)
	
	var guard_material = StandardMaterial3D.new()
	guard_material.albedo_color = Color(0.6, 0.5, 0.3)
	guard_material.metallic = 0.8
	guard_material.roughness = 0.3
	crossguard.material_override = guard_material
	
	blade.add_child(crossguard)
	weapon_parts.append(crossguard)
	
	# Handle
	var handle = MeshInstance3D.new()
	var handle_mesh = CylinderMesh.new()
	handle_mesh.top_radius = 0.04
	handle_mesh.bottom_radius = 0.045
	handle_mesh.height = 0.25
	handle.mesh = handle_mesh
	handle.position = Vector3(0, -0.5, 0)
	
	var handle_material = StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.3, 0.2, 0.1)
	handle_material.roughness = 0.8
	handle.material_override = handle_material
	
	blade.add_child(handle)
	weapon_parts.append(handle)
	
	# Pommel
	var pommel = MeshInstance3D.new()
	var pommel_mesh = SphereMesh.new()
	pommel_mesh.radius = 0.06
	pommel_mesh.height = 0.08
	pommel.mesh = pommel_mesh
	pommel.position = Vector3(0, -0.65, 0)
	pommel.material_override = guard_material
	
	blade.add_child(pommel)
	weapon_parts.append(pommel)

func _create_enhanced_bow():
	"""Create detailed bow pickup visual"""
	# Main bow frame (curved using multiple segments)
	var bow_frame = MeshInstance3D.new()
	add_child(bow_frame)
	weapon_parts.append(bow_frame)
	
	# Create bow curve using multiple small cylinders
	var segments = 8
	var bow_height = 0.8
	var bow_width = 0.3
	
	for i in range(segments):
		var segment = MeshInstance3D.new()
		var segment_mesh = CylinderMesh.new()
		segment_mesh.top_radius = 0.02
		segment_mesh.bottom_radius = 0.02
		segment_mesh.height = bow_height / segments
		segment.mesh = segment_mesh
		
		# Position segments in a bow curve
		var t = float(i) / float(segments - 1)
		var y = (t - 0.5) * bow_height
		var curve_factor = sin(t * PI) * bow_width
		segment.position = Vector3(curve_factor, y, 0)
		segment.rotation_degrees = Vector3(0, 0, sin(t * PI) * 30)
		
		var bow_material = StandardMaterial3D.new()
		bow_material.albedo_color = Color(0.4, 0.25, 0.1)
		bow_material.roughness = 0.7
		bow_material.emission_enabled = true
		bow_material.emission = Color(0.3, 0.6, 0.2) * glow_intensity * 0.2
		segment.material_override = bow_material
		
		bow_frame.add_child(segment)
		weapon_parts.append(segment)
	
	# Bow string
	var string_segment = MeshInstance3D.new()
	var string_mesh = BoxMesh.new()
	string_mesh.size = Vector3(0.01, bow_height * 0.9, 0.01)
	string_segment.mesh = string_mesh
	string_segment.position = Vector3(bow_width * 0.7, 0, 0)
	
	var string_material = StandardMaterial3D.new()
	string_material.albedo_color = Color(0.9, 0.9, 0.8)
	string_material.emission_enabled = true
	string_material.emission = Color(0.5, 0.5, 0.4) * 0.3
	string_segment.material_override = string_material
	
	bow_frame.add_child(string_segment)
	weapon_parts.append(string_segment)

func _create_enhanced_staff():
	"""Create detailed staff pickup visual"""
	# Main staff shaft
	var shaft = MeshInstance3D.new()
	var shaft_mesh = CylinderMesh.new()
	shaft_mesh.top_radius = 0.025
	shaft_mesh.bottom_radius = 0.035
	shaft_mesh.height = 1.0
	shaft.mesh = shaft_mesh
	
	var shaft_material = StandardMaterial3D.new()
	shaft_material.albedo_color = Color(0.4, 0.25, 0.1)
	shaft_material.roughness = 0.8
	shaft.material_override = shaft_material
	
	add_child(shaft)
	weapon_parts.append(shaft)
	
	# Ornate top section
	var ornate_top = MeshInstance3D.new()
	var ornate_mesh = CylinderMesh.new()
	ornate_mesh.top_radius = 0.05
	ornate_mesh.bottom_radius = 0.03
	ornate_mesh.height = 0.15
	ornate_top.mesh = ornate_mesh
	ornate_top.position = Vector3(0, 0.4, 0)
	
	var ornate_material = StandardMaterial3D.new()
	ornate_material.albedo_color = Color(0.8, 0.6, 0.2)
	ornate_material.metallic = 0.9
	ornate_material.roughness = 0.2
	ornate_material.emission_enabled = true
	ornate_material.emission = Color(0.6, 0.4, 0.1) * 0.5
	ornate_top.material_override = ornate_material
	
	shaft.add_child(ornate_top)
	weapon_parts.append(ornate_top)
	
	# Crystal orb at top
	var orb = MeshInstance3D.new()
	var orb_mesh = SphereMesh.new()
	orb_mesh.radius = 0.12
	orb_mesh.height = 0.15
	orb.mesh = orb_mesh
	orb.position = Vector3(0, 0.55, 0)
	
	var orb_material = StandardMaterial3D.new()
	orb_material.albedo_color = Color(0.3, 0.5, 1.0, 0.8)
	orb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb_material.emission_enabled = true
	orb_material.emission = Color(0.4, 0.6, 1.0) * glow_intensity
	orb_material.rim_enabled = true
	orb_material.rim = 0.8
	orb.material_override = orb_material
	
	shaft.add_child(orb)
	weapon_parts.append(orb)
	
	# Floating runes around the orb
	_create_floating_runes(orb)

func _create_floating_runes(parent: MeshInstance3D):
	"""Create floating magical runes around staff orb"""
	var rune_count = 4
	for i in range(rune_count):
		var rune = MeshInstance3D.new()
		var rune_mesh = BoxMesh.new()
		rune_mesh.size = Vector3(0.03, 0.03, 0.01)
		rune.mesh = rune_mesh
		
		# Position runes in circle around orb
		var angle = (i / float(rune_count)) * TAU
		var radius = 0.2
		rune.position = Vector3(
			cos(angle) * radius,
			sin(angle * 0.5) * 0.05,  # Slight vertical offset
			sin(angle) * radius
		)
		
		var rune_material = StandardMaterial3D.new()
		rune_material.albedo_color = Color(1.0, 0.8, 0.3)
		rune_material.emission_enabled = true
		rune_material.emission = Color(1.0, 0.8, 0.3) * 2.0
		rune_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		rune.material_override = rune_material
		
		parent.add_child(rune)
		weapon_parts.append(rune)

func _create_default_visual():
	"""Create enhanced default pickup visual"""
	var default_mesh = SphereMesh.new()
	default_mesh.radius = 0.25
	default_mesh.height = 0.35
	mesh_instance.mesh = default_mesh
	
	weapon_material = StandardMaterial3D.new()
	weapon_material.albedo_color = Color(0.7, 0.7, 0.8)
	weapon_material.emission_enabled = true
	weapon_material.emission = Color.WHITE * 0.8
	weapon_material.rim_enabled = true
	weapon_material.rim = 0.5
	mesh_instance.material_override = weapon_material
	
	weapon_parts.append(mesh_instance)

func _create_floating_text():
	"""Create floating interaction text"""
	floating_text = Label3D.new()
	floating_text.name = "FloatingText"
	floating_text.text = "Press Q to Pick Up"
	floating_text.position = Vector3(0, 1.5, 0)
	floating_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floating_text.no_depth_test = true
	floating_text.modulate = Color(1.0, 1.0, 0.4, 0.9)
	floating_text.outline_modulate = Color(0.2, 0.2, 0.0, 1.0)
	floating_text.font_size = 36
	floating_text.outline_size = 6
	floating_text.visible = false
	add_child(floating_text)

func _find_player():
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	"""Handle enhanced animations"""
	time_alive += delta
	
	# Animate all weapon parts together
	var bob_offset = sin(time_alive * bob_speed) * bob_height
	var rotation_y = rotation_speed * delta
	
	for part in weapon_parts:
		if is_instance_valid(part) and part.get_parent() == self:  # Only animate top-level parts
			part.rotation_degrees.y += rotation_y
			part.position.y = bob_offset
	
	# Enhanced glow pulsing for magical weapons
	if weapon_resource and weapon_resource.weapon_type == WeaponResource.WeaponType.STAFF:
		_animate_staff_effects(delta)

func _animate_staff_effects(delta):
	"""Special animations for staff weapons"""
	# Animate floating runes
	for part in weapon_parts:
		if part.name.begins_with("Rune") or part.get_parent().name.contains("orb"):
			var float_offset = sin(time_alive * 3.0 + part.position.x * 10) * 0.02
			part.position.y += float_offset * delta * 10
			
			# Rune rotation
			if part.material_override and part.material_override.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED:
				part.rotation_degrees.z += 45 * delta

func _input(event):
	if event.is_action_pressed("drop_weapon") and player_in_range and not get_meta("pickup_disabled", false):
		_interact_with_weapon()

func _on_area_entered(area: Area3D):
	if area.get_parent() and area.get_parent().is_in_group("player"):
		player_in_range = true
		_update_interaction_text()
		if floating_text:
			floating_text.visible = true
		print("🗡️ Player near weapon: ", weapon_resource.weapon_name if weapon_resource else "Unknown")

func _on_area_exited(area: Area3D):
	if area.get_parent() and area.get_parent().is_in_group("player"):
		player_in_range = false
		if floating_text:
			floating_text.visible = false

func _update_interaction_text():
	if not weapon_resource or not floating_text:
		return

	var weapon_name = weapon_resource.weapon_name
	var player_has_weapon = WeaponManager.is_weapon_equipped()
	
	if player_has_weapon:
		floating_text.text = "Press Q to Swap for %s" % weapon_name
		floating_text.modulate = Color(0.8, 0.8, 1.0, 0.9)
	else:
		floating_text.text = "Press Q to Pick Up %s" % weapon_name
		floating_text.modulate = Color(0.3, 1.0, 0.3, 0.9)

func _interact_with_weapon():
	if not weapon_resource:
		return
	
	print("🗡️ Interacting with weapon: ", weapon_resource.weapon_name)
	
	if WeaponManager.is_weapon_equipped():
		_swap_weapons()
	else:
		_pickup_weapon()

func _pickup_weapon():
	WeaponManager.equip_weapon(weapon_resource)
	print("🗡️ Picked up: ", weapon_resource.weapon_name)
	# Immediately update hand visuals if SimpleHandManager exists
	if Engine.has_singleton("SimpleHandManager"):
		var hand_mgr = get_node("/root/SimpleHandManager")
		if hand_mgr and hand_mgr.has_method("refresh_weapon_hands"):
			hand_mgr.refresh_weapon_hands()
	queue_free()

func _swap_weapons():
	var old_weapon = WeaponManager.get_current_weapon()
	WeaponManager.equip_weapon(weapon_resource)
	print("🗡️ Swapped to: ", weapon_resource.weapon_name)
	# Immediately update hand visuals if SimpleHandManager exists
	if Engine.has_singleton("SimpleHandManager"):
		var hand_mgr = get_node("/root/SimpleHandManager")
		if hand_mgr and hand_mgr.has_method("refresh_weapon_hands"):
			hand_mgr.refresh_weapon_hands()
	if old_weapon:
		set_weapon_resource(old_weapon)
		print("🗡️ Dropped: ", old_weapon.weapon_name)
	else:
		queue_free()

func set_weapon_resource(new_resource: WeaponResource):
	weapon_resource = new_resource
	if weapon_resource and "weapon_name" in weapon_resource:
		set_meta("weapon_name", weapon_resource.weapon_name)
	# Always setup visual when resource is set
	if is_inside_tree():
		_setup_enhanced_visual()
		if player_in_range:
			_update_interaction_text()

func _create_pickup_delay_effect(delay_time: float):
	"""Create visual effect during pickup delay"""
	print("🗡️ Weapon pickup delay effect for ", delay_time, " seconds")
	
	# Dim the weapon during delay
	for part in weapon_parts:
		if is_instance_valid(part) and part.material_override:
			var material = part.material_override as StandardMaterial3D
			if material and material.emission_enabled:
				var tween = create_tween()
				tween.set_loops(int(delay_time * 2))
				
				var dim_emission = material.emission * 0.3
				var normal_emission = material.emission
				
				tween.tween_property(material, "emission", dim_emission, 0.25)
				tween.tween_property(material, "emission", normal_emission, 0.25)
