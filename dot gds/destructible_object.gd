# destructible_object.gd - Fixed version
extends StaticBody3D

enum ObjectType { CRATE, BARREL }

# Configuration
@export var object_type: ObjectType = ObjectType.CRATE
@export var health: int = 2
@export var glow_intensity: float = 0.3

# Visual components
var mesh_instance: MeshInstance3D
var wood_material: StandardMaterial3D
var is_being_destroyed = false

# Breaking effect settings
const DEBRIS_COUNT = 8
const DEBRIS_FORCE = 4.0
const DEBRIS_LIFETIME = 1.0

func _ready():
	# Add to groups for attack detection
	add_to_group("destructibles")
	add_to_group("enemies")  # This allows player attacks to hit it
	_create_visual()
	_setup_collision()

func _create_visual():
	"""Create mesh and collision entirely in code"""
	# Remove any existing visual components
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			child.queue_free()
	
	# Create fresh mesh
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "ObjectMesh"
	add_child(mesh_instance)
	
	# Create wood material
	wood_material = StandardMaterial3D.new()
	wood_material.albedo_color = Color(0.4, 0.25, 0.1)  # Dark wood
	wood_material.roughness = 0.9
	wood_material.emission_enabled = true
	wood_material.emission = Color(0.4, 0.25, 0.1) * glow_intensity
	
	match object_type:
		ObjectType.CRATE:
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(0.8, 0.8, 0.8)
			mesh_instance.mesh = box_mesh
		ObjectType.BARREL:
			var cylinder_mesh = CylinderMesh.new()
			cylinder_mesh.top_radius = 0.4
			cylinder_mesh.bottom_radius = 0.4
			cylinder_mesh.height = 1.0
			mesh_instance.mesh = cylinder_mesh
	
	mesh_instance.material_override = wood_material

func _setup_collision():
	"""Setup collision shape for physics and attacks"""
	# Main collision for physics
	var collision = CollisionShape3D.new()
	
	match object_type:
		ObjectType.CRATE:
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(0.8, 0.8, 0.8)
			collision.shape = box_shape
		ObjectType.BARREL:
			var cylinder_shape = CylinderShape3D.new()
			cylinder_shape.radius = 0.4
			cylinder_shape.height = 1.0
			collision.shape = cylinder_shape
	
	add_child(collision)
	
	# Set collision layers to match enemies (so player attacks can hit)
	collision_layer = 2  # Same as enemies
	collision_mask = 1   # Collide with world

func take_damage(amount: int):
	"""Handle taking damage from player attacks"""
	if is_being_destroyed:
		return
	
	print("🗃️ ", name, " took ", amount, " damage!")
	health -= amount
	_show_damage_effect()
	
	if health <= 0:
		_destroy()

func _show_damage_effect():
	"""Show visual feedback when taking damage"""
	if not mesh_instance:
		return
	
	# Quick scale punch effect
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(mesh_instance, "scale", Vector3(1.2, 0.8, 1.2), 0.1)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.2).set_delay(0.1)
	
	# Flash material
	if wood_material:
		var flash_tween = create_tween()
		flash_tween.tween_property(wood_material, "emission", 
			Color(1.0, 0.5, 0.2) * glow_intensity * 3.0, 0.1)
		flash_tween.tween_property(wood_material, "emission", 
			Color(0.4, 0.25, 0.1) * glow_intensity, 0.2)

func _destroy():
	"""Handle destruction and loot drops"""
	if is_being_destroyed:
		return
	
	is_being_destroyed = true
	print("💥 Destroying ", name, "!")
	
	_create_breaking_effect()
	_drop_loot()
	
	# Clean up after effects finish
	await get_tree().create_timer(DEBRIS_LIFETIME).timeout
	queue_free()

func _create_breaking_effect():
	"""Create breaking animation and debris"""
	if not mesh_instance:
		return
	
	# Hide original mesh
	mesh_instance.visible = false
	
	# Create debris pieces
	for i in range(DEBRIS_COUNT):
		var debris = MeshInstance3D.new()
		var debris_mesh = BoxMesh.new()
		
		# Size based on object type
		var size = 0.2 if object_type == ObjectType.CRATE else 0.15
		debris_mesh.size = Vector3(size, size, size)
		debris.mesh = debris_mesh
		debris.material_override = wood_material
		
		add_child(debris)
		
		# Random position within object bounds
		var offset = Vector3(
			randf_range(-0.3, 0.3),
			randf_range(-0.3, 0.3),
			randf_range(-0.3, 0.3)
		)
		debris.position = offset
		
		# Launch debris
		var direction = offset.normalized()
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Movement
		var target_pos = debris.position + direction * DEBRIS_FORCE
		target_pos.y -= 1.0  # Fall down
		tween.tween_property(debris, "position", target_pos, DEBRIS_LIFETIME)
		
		# Rotation
		var random_rotation = Vector3(
			randf_range(-PI, PI),
			randf_range(-PI, PI),
			randf_range(-PI, PI)
		)
		tween.tween_property(debris, "rotation", random_rotation, DEBRIS_LIFETIME)
		
		# Fade out
		tween.tween_property(debris, "scale", Vector3.ZERO, 0.3).set_delay(DEBRIS_LIFETIME - 0.3)

func _drop_loot():
	"""Drop appropriate loot based on object type"""
	if not LootManager:
		print("❌ LootManager not found!")
		return

	var type_key = "crate" if object_type == ObjectType.CRATE else "barrel"
	print("🎁 Dropping loot for ", type_key)

	if LootManager.has_method("drop_destructible_loot"):
		LootManager.drop_destructible_loot(global_position, type_key)
