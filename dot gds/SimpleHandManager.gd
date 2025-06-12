extends Node3D

# Reference to the current weapon visual instance
var weapon_visual: Node3D = null

func _ready():
	# Connect to WeaponManager signals if available
	if Engine.has_singleton("WeaponManager"):
		var wm = Engine.get_singleton("WeaponManager")
		if wm.has_signal("weapon_equipped"):
			wm.connect("weapon_equipped", Callable(self, "_on_weapon_equipped"))
		if wm.has_signal("weapon_unequipped"):
			wm.connect("weapon_unequipped", Callable(self, "_on_weapon_unequipped"))
	# Initial refresh in case weapon is already equipped
	refresh_weapon_hands()

func _on_weapon_equipped(weapon_resource):
	refresh_weapon_hands()

func _on_weapon_unequipped():
	refresh_weapon_hands()

func refresh_weapon_hands():
	# Remove old visual if exists
	if weapon_visual and is_instance_valid(weapon_visual):
		weapon_visual.queue_free()
		weapon_visual = null

	var weapon_resource = null
	if Engine.has_singleton("WeaponManager"):
		var wm = Engine.get_singleton("WeaponManager")
		if wm.has_method("get_current_weapon"):
			weapon_resource = wm.get_current_weapon()
	
	if weapon_resource == null:
		return
	
	# Create a new weapon visual based on weapon_resource
	weapon_visual = _create_weapon_visual(weapon_resource)
	if weapon_visual:
		add_child(weapon_visual)
		_position_weapon_visual(weapon_visual, weapon_resource)

func _create_weapon_visual(weapon_resource):
	# This is a minimal example. You may want to expand this for your weapon types.
	var visual = MeshInstance3D.new()
	match weapon_resource.weapon_type:
		WeaponResource.WeaponType.SWORD:
			var mesh = BoxMesh.new()
			mesh.size = Vector3(0.08, 0.8, 0.15)
			visual.mesh = mesh
			visual.position = Vector3(0, 0, 0)
		WeaponResource.WeaponType.BOW:
			var mesh = CylinderMesh.new()
			mesh.top_radius = 0.03
			mesh.bottom_radius = 0.03
			mesh.height = 0.7
			visual.mesh = mesh
			visual.position = Vector3(0, 0, 0)
			visual.rotation_degrees = Vector3(0, 0, 90)
		WeaponResource.WeaponType.STAFF:
			var mesh = CylinderMesh.new()
			mesh.top_radius = 0.025
			mesh.bottom_radius = 0.035
			mesh.height = 1.0
			visual.mesh = mesh
			visual.position = Vector3(0, 0, 0)
		_:
			var mesh = SphereMesh.new()
			mesh.radius = 0.15
			visual.mesh = mesh
			visual.position = Vector3(0, 0, 0)
	return visual

func _position_weapon_visual(visual: Node3D, weapon_resource):
	# Adjust position/rotation for the hand
	match weapon_resource.weapon_type:
		WeaponResource.WeaponType.SWORD:
			visual.position = Vector3(0, 0, 0)
			visual.rotation_degrees = Vector3(0, 0, 0)
		WeaponResource.WeaponType.BOW:
			visual.position = Vector3(0, 0, 0)
			visual.rotation_degrees = Vector3(0, 0, 90)
		WeaponResource.WeaponType.STAFF:
			visual.position = Vector3(0, -0.2, 0)
			visual.rotation_degrees = Vector3(0, 0, 0)
		_:
			visual.position = Vector3(0, 0, 0)
			visual.rotation_degrees = Vector3(0, 0, 0)
