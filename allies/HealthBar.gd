extends Control

@export var max_health := 100
@export var current_health := 100

@onready var bar := $ProgressBar

func _ready():
	bar.max_value = max_health
	bar.value = current_health
	_update_bar_color()

func set_health(value, max_value):
	current_health = value
	max_health = max_value
	bar.max_value = max_health
	bar.value = current_health
	_update_bar_color()

func _update_bar_color():
	var percent := float(current_health) / float(max_health)
	var color := Color(0,1,0) # green
	if percent < 0.33:
		color = Color(1,0,0) # red
	elif percent < 0.66:
		color = Color(1,0.5,0) # orange
	# For Godot 4: ProgressBar uses add_theme_color_override
	bar.add_theme_color_override("fill_color", color)
