extends StaticBody3D

@export var ally_scene: PackedScene

var player_in_range = false

func _ready():
	# Connect the Area3D signals
	$Area3D.body_entered.connect(_on_Area3D_body_entered)
	$Area3D.body_exited.connect(_on_Area3D_body_exited)
	print("Signals connected for Area3D")

func _process(_delta):
	if Input.is_action_just_pressed("recruit"):
		print("Recruit action detected globally!")
	if player_in_range:
		print("Player is in range.")
		if Input.is_action_just_pressed("recruit"):
			print("Recruit action detected.")
			spawn_ally()
		else:
			print("Recruit action not pressed.")
	else:
		print("Player is not in range.")

func _on_Area3D_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		print("Player entered Area3D")
		# Optionally show a prompt to the player (e.g., enable the Label3D)
		if has_node("Label3D"):
			$Label3D.visible = true
	else:
		print("Non-player body entered Area3D: ", body)

func _on_Area3D_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		print("Player exited Area3D")
		# Optionally hide the prompt
		if has_node("Label3D"):
			$Label3D.visible = false
	else:
		print("Non-player body exited Area3D: ", body)

func spawn_ally():
	if ally_scene:
		var new_ally = ally_scene.instantiate()
		get_parent().add_child(new_ally)
		new_ally.global_position = global_position + Vector3(2, 0, 0) # Spawn slightly to the side
		print("Ally spawned at position: ", new_ally.global_position)
	else:
		print("Error: Ally scene not set!")
