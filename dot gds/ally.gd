# ally.gd - Simple ally that follows player and attacks enemies
extends CharacterBody3D

# Basic stats
@export var speed := 4.0
@export var follow_distance := 3.0
@export var attack_range := 2.5
@export var attack_damage := 15
@export var attack_cooldown := 1.5
@export var health := 100
@export var max_health := 100

# References
var player: CharacterBody3D
var current_target: Node3D = null
var attack_timer := 0.0

# Visual components
var mesh_instance: MeshInstance3D
var weapon_mesh: MeshInstance3D

func _ready():
	add_to_group("allies")
	_find_player()
	_create_visual()
	print("🤝 Ally spawned and ready!")

func _find_player():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("❌ Ally: Player not found!")

func _create_visual():
	# Create body
	mesh_instance = MeshInstance3D.new()
	var body_mesh = CapsuleMesh.new()
	body_mesh.radius = 0.25
	body_mesh.height = 1.4
	mesh_instance.mesh = body_mesh
	
	# Create material (blue to distinguish from enemies)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.4, 1.0)
	material.roughness = 0.7
	mesh_instance.material_override = material
	add_child(mesh_instance)
	
	# Create simple weapon
	weapon_mesh = MeshInstance3D.new()
	var sword_mesh = BoxMesh.new()
	sword_mesh.size = Vector3(0.1, 0.6, 0.1)
	weapon_mesh.mesh = sword_mesh
	weapon_mesh.position = Vector3(0.3, 0.2, 0)
	
	var weapon_material = StandardMaterial3D.new()
	weapon_material.albedo_color = Color(0.8, 0.8, 0.9)
	weapon_material.metallic = 0.9
	weapon_material.roughness = 0.2
	weapon_mesh.material_override = weapon_material
	mesh_instance.add_child(weapon_mesh)
	
	# Create collision
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.4
	collision.shape = shape
	add_child(collision)

func _physics_process(delta):
	if not player:
		return
	
	attack_timer = max(0, attack_timer - delta)
	
	# Find nearest enemy
	current_target = _find_nearest_enemy()
	
	if current_target and global_position.distance_to(current_target.global_position) <= attack_range:
		# Attack enemy
		_attack_enemy()
		velocity = Vector3.ZERO
	else:
		# Follow player
		_follow_player()
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	move_and_slide()

func _follow_player():
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player > follow_distance:
		var direction = (player.global_position - global_position).normalized()
		direction.y = 0  # Don't move vertically
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Face movement direction
		if direction.length() > 0.1:
			look_at(global_position + direction, Vector3.UP)
	else:
		# Stop when close enough
		velocity.x = 0
		velocity.z = 0

func _find_nearest_enemy() -> Node3D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_enemy: Node3D = null
	var nearest_distance := 999.0
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance and distance <= attack_range * 2:
			nearest_distance = distance
			nearest_enemy = enemy
	
	return nearest_enemy

func _attack_enemy():
	if attack_timer > 0 or not current_target:
		return
	
	# Face the enemy
	var direction = (current_target.global_position - global_position)
	direction.y = 0
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
	
	# Attack
	if current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)
		print("🗡️ Ally attacked enemy for ", attack_damage, " damage!")
	
	# Play attack animation (simple weapon swing)
	_play_attack_animation()
	
	attack_timer = attack_cooldown

func _play_attack_animation():
	if not weapon_mesh:
		return
	
	var tween = create_tween()
	tween.tween_property(weapon_mesh, "rotation_degrees", Vector3(0, 0, -45), 0.1)
	tween.tween_property(weapon_mesh, "rotation_degrees", Vector3.ZERO, 0.2)

func take_damage(amount: int):
	health -= amount
	print("🤝 Ally took ", amount, " damage! Health: ", health)
	
	if health <= 0:
		die()

func die():
	print("💀 Ally died!")
	queue_free()
