@tool
extends EditorScript

# This tool script will bake the character appearance into the scene

func _run():
	print("🔥 Character Baking Tool Started!")
	
	# Get the currently selected node in the editor
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	
	if selected_nodes.is_empty():
		print("❌ Please select the Player node in the scene first!")
		return
	
	var player = selected_nodes[0]
	if not player.is_in_group("player"):
		print("❌ Selected node is not a player! Add it to 'player' group first.")
		return
	
	print("✅ Baking character for: ", player.name)
	_bake_character_to_scene(player)

func _bake_character_to_scene(player: CharacterBody3D):
	"""Bake the character appearance directly into the scene"""
	
	# Generate random character config
	var config = CharacterGenerator.generate_random_character_config()
	
	# Clear existing baked parts
	_clear_existing_baked_parts(player)
	
	# Create and bake each part
	_bake_body(player, config)
	_bake_hands(player, config)
	_bake_feet(player, config)
	_bake_eyes(player, config)
	_bake_mouth(player, config)
	
	print("🎉 Character baked successfully! Save the scene to keep changes.")

func _clear_existing_baked_parts(player: CharacterBody3D):
	"""Remove any existing baked character parts"""
	var parts_to_remove = [
		"LeftHandAnchor/LeftHand", "RightHandAnchor/RightHand",
		"LeftFoot", "RightFoot", "MeshInstance3D/LeftEye", "MeshInstance3D/RightEye",
		"MeshInstance3D/Mouth"
	]
	
	for part_path in parts_to_remove:
		var part = player.get_node_or_null(part_path)
		if part:
			part.queue_free()

func _bake_hands(player: CharacterBody3D, config: Dictionary):
	"""Bake hands into hand anchor nodes"""
	var hands_cfg = config.get("hands", {})
	var size = hands_cfg.get("size", 0.08)
	
	# Create hands at anchors
	for side in ["Left", "Right"]:
		var anchor = player.get_node_or_null(side + "HandAnchor")
		if not anchor:
			continue
			
		var hand = MeshInstance3D.new()
		hand.name = side + "Hand"
		hand.owner = player.get_tree().edited_scene_root
		
		var mesh = BoxMesh.new()
		mesh.size = Vector3(size * 2.5, size * 1.5, size * 2.5)
		hand.mesh = mesh
		hand.rotation_degrees = Vector3(0, 0, 90)
		
		# Apply skin material
		var material = StandardMaterial3D.new()
		material.albedo_color = config.get("skin_tone", Color(0.9, 0.7, 0.6))
		hand.material_override = material
		
		anchor.add_child(hand)
		print("✅ Baked ", side, "Hand")

func _bake_feet(player: CharacterBody3D, config: Dictionary):
	"""Bake feet as children of player"""
	var feet_cfg = config.get("feet", {})
	var foot_size = Vector3(0.15, 0.06, 0.25)
	
	for i in [-1, 1]:
		var foot = MeshInstance3D.new()
		foot.name = "LeftFoot" if i < 0 else "RightFoot"
		foot.owner = player.get_tree().edited_scene_root
		
		var mesh = BoxMesh.new()
		mesh.size = Vector3(foot_size.x * 1.7, foot_size.y * 2.5, foot_size.z * 1.7)
		foot.mesh = mesh
		foot.position = Vector3(i * 0.25, -1.05 + 0.2 - 0.05, 0)
		
		var material = StandardMaterial3D.new()
		material.albedo_color = config.get("skin_tone", Color(0.9, 0.7, 0.6))
		foot.material_override = material
		
		player.add_child(foot)
		print("✅ Baked ", foot.name)

func _bake_body(player: CharacterBody3D, config: Dictionary):
	"""Update the existing MeshInstance3D with body"""
	var body_mesh_instance = player.get_node_or_null("MeshInstance3D")
	if not body_mesh_instance:
		body_mesh_instance = MeshInstance3D.new()
		body_mesh_instance.name = "MeshInstance3D"
		player.add_child(body_mesh_instance)

	body_mesh_instance.owner = player.get_tree().edited_scene_root

	# Create body mesh
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.radius = config.get("body_radius", 0.3)
	capsule_mesh.height = config.get("body_height", 1.5)
	body_mesh_instance.mesh = capsule_mesh

	# Apply skin material
	var material = StandardMaterial3D.new()
	material.albedo_color = config.get("skin_tone", Color(0.9, 0.7, 0.6))
	body_mesh_instance.material_override = material

	print("✅ Baked body")


func _bake_eyes(player: CharacterBody3D, config: Dictionary):
	"""Bake eyes as children of MeshInstance3D"""
	var mesh_instance = player.get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return
		
	var eyes_cfg = config.get("eyes", {})
	var eye_size = eyes_cfg.get("size", 0.07)
	var eye_spacing = eyes_cfg.get("spacing", 0.26)
	
	for i in [-1, 1]:
		var eye_container = Node3D.new()
		eye_container.name = "LeftEye" if i < 0 else "RightEye"
		eye_container.owner = player.get_tree().edited_scene_root
		eye_container.position = Vector3(i * eye_spacing / 2, 0.3, -0.25)
		mesh_instance.add_child(eye_container)
		
		# Create eyeball
		var eyeball = MeshInstance3D.new()
		eyeball.name = "Eyeball"
		eyeball.owner = player.get_tree().edited_scene_root
		var eye_sphere = SphereMesh.new()
		eye_sphere.radius = eye_size
		eyeball.mesh = eye_sphere
		
		var eye_material = StandardMaterial3D.new()
		eye_material.albedo_color = Color.WHITE
		eyeball.material_override = eye_material
		
		eye_container.add_child(eyeball)
		
	print("✅ Baked eyes")

func _bake_mouth(player: CharacterBody3D, config: Dictionary):
	"""Bake mouth as child of MeshInstance3D"""
	var mesh_instance = player.get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return
	
	var mouth = Node3D.new()
	mouth.name = "Mouth"
	mouth.owner = player.get_tree().edited_scene_root
	mouth.position = Vector3(0, 0.1, -0.25)
	mesh_instance.add_child(mouth)
	
	# Create 3 mouth spheres
	for i in range(3):
		var part = MeshInstance3D.new()
		part.name = "MouthSphere%d" % i
		part.owner = player.get_tree().edited_scene_root
		
		var sphere = SphereMesh.new()
		sphere.radius = 0.05
		part.mesh = sphere
		
		var positions = [Vector3(-0.08, 0, 0), Vector3(0, 0, 0), Vector3(0.08, 0, 0)]
		part.position = positions[i]
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.1, 0.08, 0.07)
		part.material_override = material
		
		mouth.add_child(part)
	
	print("✅ Baked mouth")
