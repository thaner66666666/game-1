# This script adds a SpeedLabel to the UI scene in code for reference
# In Godot editor, you can do this visually as well.

func _add_speed_label_to_ui(ui_node):
	var speed_label = Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.text = "Speed: 0.0"
	speed_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	speed_label.anchor_right = 1.0
	speed_label.anchor_top = 0.0
	speed_label.anchor_bottom = 0.0
	speed_label.offset_right = -20
	speed_label.offset_top = 20
	speed_label.add_theme_font_size_override("font_size", 16)
	ui_node.add_child(speed_label)

# Usage: Call _add_speed_label_to_ui(get_node("/root/YourMainUI")) in your main UI scene's _ready()
# Or add the Label visually in the Godot editor as described.
