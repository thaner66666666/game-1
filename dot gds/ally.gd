extends CharacterBody3D

# Declare member variables here. Examples:
var speed = 4
var jump_height = 4
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Weapon system variables
var weapon_attach_point: Node = null
var ally_weapon_resource: Resource = null
var _weapon_instance: Node = null

# Called when the node enters the scene tree for the first time.
func _ready():
	# Setup weapon attach point (copy from player.gd)
	weapon_attach_point = $Skeleton3D/BoneAttachment3D_Weapon
	# Equip iron sword by default
	var iron_sword = load("res://Weapons/iron_sword.tres")
	equip_weapon(iron_sword)

func _process(delta):
	# Add your per-frame logic here.
	pass

func _physics_process(delta):
	# Add your per-frame physics logic here.
	pass

func equip_weapon(weapon: Resource) -> void:
	if has_weapon():
		_hide_weapon_visual()
	ally_weapon_resource = weapon
	_show_weapon_visual()

func get_current_weapon() -> Resource:
	return ally_weapon_resource

func has_weapon() -> bool:
	return ally_weapon_resource != null

func _show_weapon_visual() -> void:
	if not weapon_attach_point or not ally_weapon_resource:
		return
	# Remove previous weapon instance if any
	if _weapon_instance and _weapon_instance.is_inside_tree():
		_weapon_instance.queue_free()
	# Instance weapon scene/resource
	if ally_weapon_resource.has_method("instantiate"):
		_weapon_instance = ally_weapon_resource.instantiate()
	elif ally_weapon_resource is PackedScene:
		_weapon_instance = ally_weapon_resource.instance()
	else:
		return
	weapon_attach_point.add_child(_weapon_instance)
	_weapon_instance.owner = get_tree().current_scene

func _hide_weapon_visual() -> void:
	if _weapon_instance and _weapon_instance.is_inside_tree():
		_weapon_instance.queue_free()
		_weapon_instance = null
