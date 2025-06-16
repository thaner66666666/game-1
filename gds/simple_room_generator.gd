extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func generate_starting_room(room_data):
    # ...existing code...
    # Spawn treasure chest
    # ...existing code...

    # Spawn recruiter NPC at room edge, avoiding overlap with chest
    var recruiter_scene = preload("res://Scenes/recruiter_npc.tscn")
    var recruiter_position = _find_safe_object_position_no_overlap(room_data, edge=true)
    if recruiter_position != null:
        var recruiter = recruiter_scene.instantiate()
        recruiter.global_transform.origin = recruiter_position
        room_data.node.add_child(recruiter)

    # ...existing code...

func generate_room(room_data):
    # ...existing code...
    # Do NOT spawn recruiter in later rooms
    # ...existing code...