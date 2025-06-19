extends Control

var current_options: Array = []
var player_progression: PlayerProgression

@onready var button1 = $Button1  # Replace with your actual button paths
@onready var button2 = $Button2
@onready var button3 = $Button3

func _ready():
	add_to_group("levelupui")
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
func show_upgrade_choices(options: Array):
	current_options = options
	visible = true
	
	# Update button texts
	button1.text = options[0].title + "\n" + options[0].description
	button2.text = options[1].title + "\n" + options[1].description  
	button3.text = options[2].title + "\n" + options[2].description
	
func _on_button_1_pressed():
	_choose_upgrade(0)
	
func _on_button_2_pressed():
	_choose_upgrade(1)
	
func _on_button_3_pressed():
	_choose_upgrade(2)

func _choose_upgrade(index: int):
	var player = get_tree().get_first_node_in_group("player")
	if player and player.progression_component:
		player.progression_component.apply_upgrade(current_options[index])
	visible = false
