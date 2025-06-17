extends Node
class_name PlayerProgression

signal coin_collected(amount: int)
signal xp_changed(xp: int, xp_to_next: int, level: int)

var currency: int = 0
var total_coins_collected: int = 0
var xp: int = 0
var level: int = 1
var xp_to_next_level: int = 100
var xp_growth: float = 1.5

var player_ref: CharacterBody3D

func setup(player_ref_in: CharacterBody3D):
	player_ref = player_ref_in
	currency = 0
	total_coins_collected = 0

func add_currency(amount: int):
	currency += amount
	total_coins_collected += amount
	coin_collected.emit(currency)

func add_xp(amount: int):
	xp += amount
	xp_changed.emit(xp, xp_to_next_level, level)
	if xp >= xp_to_next_level:
		_level_up()

func _level_up():
	xp -= xp_to_next_level
	level += 1
	xp_to_next_level = int(xp_to_next_level * xp_growth)
	# Full heal on level up
	if player_ref.health_component:
		player_ref.health_component.current_health = player_ref.max_health
		player_ref.health_component.health_changed.emit(player_ref.health_component.current_health, player_ref.max_health)
	xp_changed.emit(xp, xp_to_next_level, level)

func get_currency() -> int:
	return currency

func get_xp() -> int:
	return xp
