extends Control

@export var max_health := 100
@export var current_health := 100

@onready var bar := $ProgressBar

func _ready():
	bar.max_value = max_health
	bar.value = current_health

func set_health(value, max_value):
	current_health = value
	max_health = max_value
	bar.max_value = max_health
	bar.value = current_health
