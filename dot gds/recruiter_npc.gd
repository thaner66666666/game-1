# recruiter_npc.gd - Simple NPC that spawns allies
extends StaticBody3D

@export var ally_scene: PackedScene = preload("res://Scenes/ally.tscn")
@export var recruitment_cost := 0  # Could add coin cost later
@export var max_allies := 3

var player_in_range := false
var interaction_text: Label3D

func _ready():
	add_to_group("npcs")
	_setup_visual()
	_setup_interaction_area()
	print("👤 Recruiter NPC ready!")

func _setup_visual():
	# Create NPC body (taller than ally, different color)
	var mesh_instance = MeshInstance3D.new()
	var body_mesh = CapsuleMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 1.8
	mesh_instance.mesh = body_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.5, 0.2)  # Brown/tan color
	material.roughness = 0.8
	mesh_instance.material_override = material
	add_child(mesh_instance)
	
	# Create collision
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.8
	collision.shape = shape
	add_child(collision)
	
	# Create floating text
	interaction_text = Label3D.new()
	interaction_text.text = "Press E to Recruit Ally"
	interaction_text.position = Vector3(0, 2.5, 0)
	interaction_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interaction_text.modulate = Color(0.2, 1.0, 0.2)
	interaction_text.font_size = 48
	interaction_text.visible = false
	add_child(interaction_text)

func _setup_interaction_area():
	var area = Area3D.new()
	area.name = "InteractionArea"
	add_child(area)
	
	var area_collision = CollisionShape3D.new()
	var area_shape = SphereShape3D.new()
	area_shape.radius = 2.0
	area_collision.shape = area_shape
	area.add_child(area_collision)
	
	# Connect signals
	area.body_entered.connect(_on_player_entered)
	area.body_exited.connect(_on_player_exited)

func _on_player_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		interaction_text.visible = true
		print("👤 Player can recruit ally")

func _on_player_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		interaction_text.visible = false

func _input(event):
	if event.is_action_pressed("interaction") and player_in_range:
		recruit_ally()

func recruit_ally():
	# Check if we have too many allies
	var current_allies = get_tree().get_nodes_in_group("allies")
	if current_allies.size() >= max_allies:
		print("👤 Too many allies! Maximum: ", max_allies)
		return
	
	# Spawn ally
	if ally_scene:
		var new_ally = ally_scene.instantiate()
		get_parent().add_child(new_ally)
		
		# Position ally next to recruiter
		new_ally.global_position = global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		
		print("👤 Recruited new ally! Total allies: ", current_allies.size() + 1)
	else:
		print("❌ No ally scene assigned!")
