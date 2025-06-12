extends Node3D

# Reference to the current weapon visual instance
var weapon_visual: Node3D = null

func _ready():
	# Connect to WeaponManager signals
	if WeaponManager:
		if WeaponManager.has_signal("weapon_equipped"):
			WeaponManager.weapon_equipped.connect(_on_weapon_equipped)
		if WeaponManager.has_signal("weapon_unequipped"):
			WeaponManager.weapon_unequipped.connect(_on_weapon_unequipped)
		print("✅ SimpleHandManager: Connected to WeaponManager signals")
	
	# Initial refresh in case weapon is already equipped
	refresh_weapon_hands()

func _on_weapon_equipped(weapon_resource: WeaponResource):
	refresh_weapon_hands()

func _on_weapon_unequipped():
	refresh_weapon_hands()

func refresh_weapon_hands():
	# Remove old visual if exists
	_clear_weapon_visual()
	
	# Get current weapon from WeaponManager
	var weapon_resource = null
	if WeaponManager and WeaponManager.has_method("get_current_weapon"):
		weapon_resource = WeaponManager.get_current_weapon()
	
	if weapon_resource == null:
		print("🤷 SimpleHandManager: No weapon equipped")
		return
	
	# Create new weapon visual
	weapon_visual = _create_weapon_visual(weapon_resource)
	if weapon_visual:
		add_child(weapon_visual)
		_position_weapon_visual(weapon_visual, weapon_resource)
		print("✅ SimpleHandManager: Created visual for ", weapon_resource.weapon_name)
	else:
		print("❌ SimpleHandManager: Failed to create visual for ", weapon_resource.weapon_name)

func _clear_weapon_visual():
	if weapon_visual and is_instance_valid(weapon_visual):
		weapon_visual.queue_free()
		weapon_visual = null

func _create_weapon_visual(weapon_resource: WeaponResource) -> Node3D:
	if not weapon_resource:
		return null
	
	var visual = MeshInstance3D.new()
	visual.name = "WeaponVisual"
	
	# Create mesh and material based on weapon type
	match int(weapon_resource.weapon_type):
		int(WeaponResource.WeaponType.SWORD):
			_create_sword_mesh(visual)
		int(WeaponResource.WeaponType.BOW):
			_create_bow_mesh(visual)
		int(WeaponResource.WeaponType.STAFF):
			_create_staff_mesh(visual)
		_:
			_create_sword_mesh(visual)
	
	return visual

func _create_sword_mesh(visual: MeshInstance3D):
	# Create sword blade
	var blade = BoxMesh.new()
	blade.size = Vector3(0.08, 1.2, 0.15)
	visual.mesh = blade
	
	# Sword material - metallic silver
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.85, 0.9)
	material.metallic = 0.9
	material.roughness = 0.2
	material.emission_enabled = true
	material.emission = Color(0.7, 0.8, 1.0) * 0.1
	visual.material_override = material

func _create_bow_mesh(visual: MeshInstance3D):
	# Create bow as a curved arc using multiple segments
	var bow_container = Node3D.new()
	visual.add_child(bow_container)
	
	# Create bow curve with multiple small cylinders
	var segments = 6
	var bow_height = 1.0
	var bow_width = 0.4
	
	for i in range(segments):
		var segment = MeshInstance3D.new()
		var segment_mesh = CylinderMesh.new()
		segment_mesh.top_radius = 0.02
		segment_mesh.bottom_radius = 0.02
		segment_mesh.height = bow_height / segments
		segment.mesh = segment_mesh
		
		# Position segments in bow curve
		var t = float(i) / float(segments - 1)
		var y = (t - 0.5) * bow_height
		var curve_factor = sin(t * PI) * bow_width * 0.5
		segment.position = Vector3(curve_factor, y, 0)
		segment.rotation_degrees = Vector3(0, 0, sin(t * PI) * 25)
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.4, 0.25, 0.1)
		material.roughness = 0.8
		segment.material_override = material
		
		bow_container.add_child(segment)
	
	# Bow string
	var string_segment = MeshInstance3D.new()
	var string_mesh = BoxMesh.new()
	string_mesh.size = Vector3(0.005, bow_height * 0.9, 0.005)
	string_segment.mesh = string_mesh
	string_segment.position = Vector3(bow_width * 0.35, 0, 0)
	
	var string_material = StandardMaterial3D.new()
	string_material.albedo_color = Color(0.9, 0.9, 0.8)
	string_segment.material_override = string_material
	
	bow_container.add_child(string_segment)

func _create_staff_mesh(visual: MeshInstance3D):
	# Create staff shaft
	var staff = CylinderMesh.new()
	staff.top_radius = 0.025
	staff.bottom_radius = 0.035
	staff.height = 1.4
	visual.mesh = staff
	
	# Staff material - dark wood with magic glow
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.2, 0.1)
	material.roughness = 0.7
	material.emission_enabled = true
	material.emission = Color(0.4, 0.6, 1.0) * 0.2
	visual.material_override = material
	
	# Add crystal orb at top
	var orb = MeshInstance3D.new()
	var orb_mesh = SphereMesh.new()
	orb_mesh.radius = 0.08
	orb.mesh = orb_mesh
	orb.position = Vector3(0, 0.8, 0)
	
	var orb_material = StandardMaterial3D.new()
	orb_material.albedo_color = Color(0.3, 0.5, 1.0, 0.8)
	orb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb_material.emission_enabled = true
	orb_material.emission = Color(0.4, 0.6, 1.0) * 0.8
	orb.material_override = orb_material
	
	visual.add_child(orb)

func _position_weapon_visual(visual: Node3D, weapon_resource: WeaponResource):
	if not visual or not weapon_resource:
		return
	
	# Position and rotate based on weapon type
	match int(weapon_resource.weapon_type):
		int(WeaponResource.WeaponType.SWORD):
			visual.position = Vector3(0, 0.6, 0)      # Blade extends up
			visual.rotation_degrees = Vector3(0, 0, 0) # Straight up
			
		int(WeaponResource.WeaponType.BOW):
			visual.position = Vector3(0, 0.5, 0)      # Center in hand
			visual.rotation_degrees = Vector3(0, 0, 0) # Vertical bow
			
		int(WeaponResource.WeaponType.STAFF):
			visual.position = Vector3(0, 0.7, 0)     # Staff extends up
			visual.rotation_degrees = Vector3(0, 0, 0) # Straight up
			
		_:
			visual.position = Vector3(0, 0.5, 0)
			visual.rotation_degrees = Vector3(0, 0, 0)
