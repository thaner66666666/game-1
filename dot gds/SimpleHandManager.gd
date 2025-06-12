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
			_create_default_mesh(visual)
	
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
	# Create bow shaft
	var bow = CylinderMesh.new()
	bow.top_radius = 0.06       # Thick enough to see
	bow.bottom_radius = 0.06
	bow.height = 1.2            # Tall enough to see
	visual.mesh = bow
	
	# Bow material - wooden brown
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.25, 0.1)
	material.roughness = 0.8
	material.emission_enabled = true
	material.emission = Color(0.3, 0.6, 0.2) * 0.1
	visual.material_override = material

func _create_staff_mesh(visual: MeshInstance3D):
	# Create staff shaft
	var staff = CylinderMesh.new()
	staff.top_radius = 0.04
	staff.bottom_radius = 0.06
	staff.height = 1.5
	visual.mesh = staff
	
	# Staff material - dark wood with magic glow
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.2, 0.1)
	material.roughness = 0.7
	material.emission_enabled = true
	material.emission = Color(0.4, 0.6, 1.0) * 0.2
	visual.material_override = material

func _create_default_mesh(visual: MeshInstance3D):
	# Fallback - simple box
	var box = BoxMesh.new()
	box.size = Vector3(0.1, 0.8, 0.1)
	visual.mesh = box
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	visual.material_override = material

func _position_weapon_visual(visual: Node3D, weapon_resource: WeaponResource):
	if not visual or not weapon_resource:
		return
	
	# Position and rotate based on weapon type
	match int(weapon_resource.weapon_type):
		int(WeaponResource.WeaponType.SWORD):
			visual.position = Vector3(0, 0.6, 0)      # Blade extends up
			visual.rotation_degrees = Vector3(0, 0, 0) # Straight up
			
		int(WeaponResource.WeaponType.BOW):
			visual.position = Vector3(0, 0.6, 0)      # Center in hand
			visual.rotation_degrees = Vector3(0, 0, 0) # Vertical bow
			
		int(WeaponResource.WeaponType.STAFF):
			visual.position = Vector3(0, 0.75, 0)     # Staff extends up
			visual.rotation_degrees = Vector3(0, 0, 0) # Straight up
			
		_:
			visual.position = Vector3(0, 0.4, 0)
			visual.rotation_degrees = Vector3(0, 0, 0)
