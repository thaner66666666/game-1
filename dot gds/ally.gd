extends CharacterBody3D

# Movement and physics variables
var speed = 4
var jump_height = 4
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Following behavior variables
var follow_distance = 3.0  # How far from the player to maintain
var player: Node = null
var following = true

# Combat variables
var attack_cooldown = 1.0
var attack_damage = 10
var attack_range = 2.5
var can_attack = true
var _attack_timer := 0.0

# XP and Leveling properties
signal ally_xp_changed(new_xp, new_level)

var ally_xp := 0
var ally_level := 1
var ally_xp_to_next_level := 100

# Weapon system variables
var weapon_attach_point: Node = null
var ally_weapon_resource: Resource = null
var _weapon_instance: Node = null

# Called when the node enters the scene tree for the first time.
func _ready():
	# Setup weapon attach point (copy from player.gd)
	weapon_attach_point = $Skeleton3D/BoneAttachment3D_Weapon
	# Find player reference
	player = get_tree().get_nodes_in_group("player")[0]
	# Equip iron sword by default
	var iron_sword = load("res://Weapons/iron_sword.tres")
	equip_weapon(iron_sword)

func _process(_delta):
	if _attack_timer > 0:
		_attack_timer -= _delta

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if player and following:
		var direction = global_position.direction_to(player.global_position)
		var distance = global_position.distance_to(player.global_position)
		
		# Only move if we're too far from the player
		if distance > follow_distance:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
			
		# Look at player
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z))
	
	move_and_slide()
	check_for_enemies()

func check_for_enemies():
	if _attack_timer > 0:
		return
	
	# Check for enemies in range and in cone
	var origin = global_transform.origin
	var forward = -global_transform.basis.z
	var cone_angle = deg_to_rad(60) # Corrected function name
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.has_method("take_damage"):
			continue
		var to_enemy = enemy.global_transform.origin - origin
		var dist = to_enemy.length()
		if dist > attack_range:
			continue
		var dir = to_enemy.normalized()
		if forward.dot(dir) < cos(cone_angle * 0.5):
			continue
		try_attack()
		break

func try_attack():
	if _attack_timer <= 0:
		_play_attack_animation()
		_damage_enemies_in_cone()
		_attack_timer = attack_cooldown

func _play_attack_animation():
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("attack")

func _damage_enemies_in_cone():
	var origin = global_transform.origin
	var forward = -global_transform.basis.z
	var cone_angle = deg_to_rad(60) # Corrected function name
	var hit = false
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.has_method("take_damage"):
			continue
		var to_enemy = enemy.global_transform.origin - origin
		var dist = to_enemy.length()
		if dist > attack_range:
			continue
		var dir = to_enemy.normalized()
		if forward.dot(dir) < cos(cone_angle * 0.5):
			continue
		var killed = enemy.take_damage(attack_damage)
		if killed:
			var xp = enemy.xp_value if enemy.has("xp_value") else 10
			add_xp(xp)
		hit = true
	return hit

func add_xp(amount: int) -> void:
	ally_xp += amount
	emit_signal("ally_xp_changed", ally_xp, ally_level)
	while ally_xp >= ally_xp_to_next_level:
		ally_xp -= ally_xp_to_next_level
		_level_up()

func _level_up() -> void:
	ally_level += 1
	ally_xp_to_next_level = int(ally_xp_to_next_level * 1.2)
	attack_damage += 2
	if has_method("increase_max_health"):
		# increase_max_health(10) # Removed this line as the function is not defined here
		pass # Added pass to maintain structure
	emit_signal("ally_xp_changed", ally_xp, ally_level)

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
