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

func _on_weapon_equipped(_weapon_resource: WeaponResource):
	refresh_weapon_hands()

func _on_weapon_unequipped():
	refresh_weapon_hands()

func refresh_weapon_hands():
	ensure_weapon_nodes()
	_hide_all_weapons()
	
	var attach_point = get_parent()
	var weapon_resource = null
	if WeaponManager and WeaponManager.has_method("get_current_weapon"):
		weapon_resource = WeaponManager.get_current_weapon()
	if weapon_resource == null:
		print("🤷 SimpleHandManager: No weapon equipped")
		return
	
	var weapon_type = int(weapon_resource.weapon_type)
	var weapon_node_name = ""
	match weapon_type:
		int(WeaponResource.WeaponType.SWORD):
			weapon_node_name = "SwordNode"
		int(WeaponResource.WeaponType.BOW):
			weapon_node_name = "BowNode"
		int(WeaponResource.WeaponType.STAFF):
			weapon_node_name = "StaffNode"
		_:
			weapon_node_name = "SwordNode"
	
	var weapon_node = attach_point.get_node_or_null(weapon_node_name)
	if weapon_node:
		# Only show if it already has a mesh (imported model)
		if weapon_node.mesh:
			weapon_node.visible = true
			_apply_enhanced_materials(weapon_node, weapon_type)
			print("✅ SimpleHandManager: Activated ", weapon_node_name)
		else:
			print("⚠️ Weapon node has no mesh: ", weapon_node_name)
	else:
		print("❌ SimpleHandManager: Could not find node ", weapon_node_name)

func _apply_enhanced_materials(weapon_node: Node, weapon_type: int):
	# Apply materials based on weapon type
	if weapon_type == int(WeaponResource.WeaponType.SWORD):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.85, 0.9)
		mat.metallic = 0.9
		mat.roughness = 0.2
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.8, 1.0) * 0.2
		weapon_node.material_override = mat
	elif weapon_type == int(WeaponResource.WeaponType.BOW):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.25, 0.1)
		mat.roughness = 0.8
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.5, 0.2) * 0.1
		weapon_node.material_override = mat
	elif weapon_type == int(WeaponResource.WeaponType.STAFF):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.2, 0.1)
		mat.roughness = 0.7
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.6, 1.0) * 0.3
		weapon_node.material_override = mat

func ensure_weapon_nodes():
	var attach_point = get_parent()
	if not attach_point:
		return

	# Don't create any fallback meshes - only work with existing imported weapon nodes
	var weapon_nodes = ["SwordNode", "BowNode", "StaffNode"]
	
	for node_name in weapon_nodes:
		var existing_node = attach_point.get_node_or_null(node_name)
		if existing_node:
			print("Found existing weapon node: ", node_name)
		else:
			print("Missing weapon node: ", node_name, " - using imported model only")

func _hide_all_weapons():
	var attach_point = get_parent()
	if attach_point:
		var names = ["SwordNode", "BowNode", "StaffNode"]
		for node_name in names:
			var node = attach_point.get_node_or_null(node_name)
			if node:
				node.visible = false
