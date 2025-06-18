extends Node
class_name PlayerProgression

# Get player node reference using get_parent() in Godot 4
@onready var player_ref = get_parent()

signal coin_collected(amount: int)
signal xp_changed(xp: int, xp_to_next: int, level: int)
signal level_up_stats(health_increase: int, damage_increase: int)

var currency: int = 0
var total_coins_collected: int = 0
var xp: int = 0
var level: int = 1
var xp_to_next_level: int = 100
var xp_growth: float = 1.5

func setup(player_ref_in: CharacterBody3D):
	player_ref = player_ref_in
	currency = 0
	total_coins_collected = 0

func add_currency(amount: int):
	if not player_ref:
		push_error("PlayerProgression: No valid player reference")
		return
	currency += amount
	total_coins_collected += amount
	coin_collected.emit(currency)

func add_xp(amount: int):
	if not player_ref:
		push_error("PlayerProgression: No valid player reference")
		return
	xp += amount
	xp_changed.emit(xp, xp_to_next_level, level)
	if xp >= xp_to_next_level:
		_level_up()

func _level_up():
	xp -= xp_to_next_level
	level += 1
	xp_to_next_level = int(xp_to_next_level * xp_growth)
	# Emit level up signal with stat increases instead of direct modification
	level_up_stats.emit(10, 5)  # Increase health by 10, damage by 5
	print("Leveled up to level ", level)
	xp_changed.emit(xp, xp_to_next_level, level)

func get_currency() -> int:
	return currency

func get_xp() -> int:
	return xp
