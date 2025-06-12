
# damage_numbers.gd - Following damage numbers
extends Node

@export var damage_font_size = 24
@export var float_height = 1.5
@export var fade_duration = 1.0
@export var combine_window := 0.5 # seconds to wait for more hits

const DAMAGE_COLORS = {
	"normal": Color.WHITE,
	"high": Color.YELLOW,
	"critical": Color.ORANGE,
	"massive": Color.RED,
	"heal": Color.GREEN
}

var floating_labels: Dictionary = {}
var label_last_position: Dictionary = {}
var label_timers: Dictionary = {} # entity: last_hit_time (seconds)
var label_fading: Dictionary = {} # entity: bool

@onready var current_scene = get_tree().current_scene
@onready var camera = get_viewport().get_camera_3d()

func _ready():
	add_to_group("damage_numbers")

func _process(_delta):
	var now = Time.get_ticks_msec() / 1000.0
	for entity in floating_labels.keys().duplicate():
		var label = floating_labels[entity] as Label
		if is_instance_valid(entity):
			_update_label_position(label, entity)
			label_last_position[entity] = entity.global_position
		elif is_instance_valid(label):
			# Entity gone, keep showing label at last known position
			if entity in label_last_position:
				var world_pos = label_last_position[entity] + Vector3(0, float_height, 0)
				var screen_pos = _world_to_screen(world_pos)
				if screen_pos != Vector2(-1, -1):
					label.position = screen_pos - (label.size / 2)
					label.visible = true
				else:
					label.visible = false
		else:
			_clear_entity_data(entity)
			continue

		# Handle combine window and fade out
		if entity in label_timers and is_instance_valid(label):
			var time_since_last = now - label_timers[entity]
			if not label_fading.get(entity, false) and time_since_last > combine_window:
				label_fading[entity] = true
				_start_fade(label, entity)

func show_damage(damage_amount: int, entity: Node3D, damage_type: String = "normal"):
	_create_or_update_label(entity, str(damage_amount), damage_type)

func show_heal(heal_amount: int, entity: Node3D):
	_create_or_update_label(entity, "+" + str(heal_amount), "heal")

func _create_or_update_label(entity: Node3D, text: String, damage_type: String):
	var label: Label
	var now = Time.get_ticks_msec() / 1000.0

	if entity in floating_labels:
		label = floating_labels[entity] as Label
		if is_instance_valid(label):
			_update_existing_label(label, text)
			label_timers[entity] = now # Reset combine window timer
			label_fading[entity] = false
			label.modulate.a = 1.0
			return
		else:
			_clear_entity_data(entity)

	label = _create_label(text, damage_type)
	floating_labels[entity] = label
	current_scene.add_child(label)
	_update_label_position(label, entity)
	label_last_position[entity] = entity.global_position
	label_timers[entity] = now
	label_fading[entity] = false
	# Don't start fade here; handled in _process

func _create_label(text: String, damage_type: String) -> Label:
	var label = Label.new()
	label.text = text
	label.size = Vector2(120, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_index = 100
	
	label.add_theme_font_size_override("font_size", damage_font_size)
	label.add_theme_color_override("font_color", DAMAGE_COLORS.get(damage_type, DAMAGE_COLORS["normal"]))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	
	return label

func _update_existing_label(label: Label, new_text: String):
	var current = label.text.to_int() if not label.text.begins_with("+") else label.text.substr(1).to_int()
	var new_val = new_text.to_int() if not new_text.begins_with("+") else new_text.substr(1).to_int()
	var total = current + new_val
	
	if new_text.begins_with("+"):
		label.text = "+" + str(total)
	else:
		label.text = str(total)
	
	label.scale = Vector2(1.3, 1.3)
	label.modulate.a = 1.0
	
	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)

func _update_label_position(label: Label, entity: Node3D):
	var world_pos = entity.global_position + Vector3(0, float_height, 0)
	var screen_pos = _world_to_screen(world_pos)
	if screen_pos == Vector2(-1, -1):
		label.visible = false
		return
	label.position = screen_pos - (label.size / 2)
	label.visible = true

func _world_to_screen(world_pos: Vector3) -> Vector2:
	if not camera:
		return Vector2(-1, -1)
	var cam_transform = camera.global_transform
	var to_point = world_pos - cam_transform.origin
	if to_point.dot(-cam_transform.basis.z) < 0:
		return Vector2(-1, -1)
	return camera.unproject_position(world_pos)

func _start_fade(label: Label, entity):
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, fade_duration)
	await tween.finished
	_clear_entity_data(entity)

func _clear_entity_data(entity):
	if entity in floating_labels:
		var label = floating_labels[entity] as Label
		if is_instance_valid(label):
			label.queue_free()
	floating_labels.erase(entity)
	label_timers.erase(entity)
	label_last_position.erase(entity)
	label_fading.erase(entity)
