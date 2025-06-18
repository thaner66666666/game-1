extends Node
class_name PlayerInventory

signal weapon_equipped(weapon_resource: WeaponResource)
signal weapon_unequipped()

var player_ref: CharacterBody3D
var weapon_attach_point: Node3D
var equipped_weapon_mesh: MeshInstance3D
var sword_node: MeshInstance3D = null

# Base stats for weapon system
var base_attack_damage := 10
var base_attack_range := 2.0
var base_attack_cooldown := 1.0
var base_attack_cone_angle := 90.0

func setup(player_ref_in: CharacterBody3D):
	player_ref = player_ref_in
	call_deferred("_setup_weapon_attach_point")
	call_deferred("_connect_weapon_manager_signals")

func _setup_weapon_attach_point():
	if not player_ref:
		return
	weapon_attach_point = player_ref.get_node_or_null("WeaponAttachPoint")
	if weapon_attach_point:
		sword_node = weapon_attach_point.get_node_or_null("SwordNode")
		if sword_node:
			print("✅ PlayerInventory: Found SwordNode")
		else:
			print("⚠️ PlayerInventory: SwordNode not found under WeaponAttachPoint")
	else:
		print("❌ PlayerInventory: WeaponAttachPoint not found on player")

func _connect_weapon_manager_signals():
	if WeaponManager:
		if not WeaponManager.weapon_equipped.is_connected(_on_weapon_equipped):
			WeaponManager.weapon_equipped.connect(_on_weapon_equipped)
		if not WeaponManager.weapon_unequipped.is_connected(_on_weapon_unequipped):
			WeaponManager.weapon_unequipped.connect(_on_weapon_unequipped)
	
	# Show weapon if already equipped at start
	if WeaponManager and WeaponManager.is_weapon_equipped():
		_on_weapon_equipped(WeaponManager.get_current_weapon())

func _on_weapon_equipped(weapon_resource):
	_show_weapon_visual(weapon_resource)
	_update_player_stats(weapon_resource)
	weapon_equipped.emit(weapon_resource)

func _on_weapon_unequipped():
	_hide_weapon_visual()
	_reset_player_stats()
	weapon_unequipped.emit()

func _show_weapon_visual(weapon_resource):
	_hide_weapon_visual()
	if not weapon_resource or not weapon_attach_point:
		return
	
	match int(weapon_resource.weapon_type):
		int(WeaponResource.WeaponType.SWORD):
			if sword_node:
				sword_node.visible = true
				equipped_weapon_mesh = sword_node
		int(WeaponResource.WeaponType.BOW):
			var bow_node = weapon_attach_point.get_node_or_null("BowNode")
			if bow_node:
				bow_node.visible = true
				equipped_weapon_mesh = bow_node
		int(WeaponResource.WeaponType.STAFF):
			var mesh = _create_simple_staff_mesh()
			if mesh:
				weapon_attach_point.add_child(mesh)
				equipped_weapon_mesh = mesh

func _hide_weapon_visual():
	if sword_node:
		sword_node.visible = false
	
	var bow_node = weapon_attach_point.get_node_or_null("BowNode") if weapon_attach_point else null
	if bow_node:
		bow_node.visible = false
	
	var staff_node = weapon_attach_point.get_node_or_null("StaffNode") if weapon_attach_point else null
	if staff_node:
		staff_node.visible = false
	
	if (equipped_weapon_mesh and 
		is_instance_valid(equipped_weapon_mesh) and 
		equipped_weapon_mesh != sword_node and 
		equipped_weapon_mesh != bow_node and 
		equipped_weapon_mesh != staff_node):
		equipped_weapon_mesh.queue_free()
	
	equipped_weapon_mesh = null

func _create_simple_staff_mesh() -> MeshInstance3D:
	var staff = MeshInstance3D.new()
	var staff_mesh = CylinderMesh.new()
	staff_mesh.top_radius = 0.025
	staff_mesh.bottom_radius = 0.035
	staff_mesh.height = 0.9
	staff.mesh = staff_mesh
	staff.position = Vector3(0, 0.45, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.25, 0.1)
	staff.material_override = mat
	return staff

func _update_player_stats(weapon_resource: WeaponResource):
	if player_ref:
		player_ref.attack_damage = base_attack_damage + weapon_resource.damage_bonus
		player_ref.attack_range = base_attack_range + weapon_resource.range_bonus
		player_ref.attack_cooldown = base_attack_cooldown * weapon_resource.cooldown_multiplier
		player_ref.attack_cone_angle = base_attack_cone_angle

func _reset_player_stats():
	if player_ref:
		player_ref.attack_damage = base_attack_damage
		player_ref.attack_range = base_attack_range
		player_ref.attack_cooldown = base_attack_cooldown
		player_ref.attack_cone_angle = base_attack_cone_angle
