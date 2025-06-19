extends Control

func _on_damage_button_pressed() -> void:
	get_tree().get_first_node_in_group("player").progression_component.apply_stat_choice("damage")
	hide()

func _on_speed_button_pressed() -> void:
	get_tree().get_first_node_in_group("player").progression_component.apply_stat_choice("speed")
	hide()

func _on_attack_speed_button_pressed() -> void:
	get_tree().get_first_node_in_group("player").progression_component.apply_stat_choice("attack_speed")
	hide()
