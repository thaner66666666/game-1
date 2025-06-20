extends Control

var max_allies := 3
var current_allies := 0

func _ready():
	update_counter()

func update_counter():
	$Label.text = str(current_allies, " / ", max_allies)

func set_allies_count(current, max_allies_param):
	current_allies = current
	max_allies = max_allies_param
	update_counter()
