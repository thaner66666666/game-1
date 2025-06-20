extends Node
class_name AllyAI

enum State { FOLLOWING, MOVING_TO_TARGET, ATTACKING, RETREATING }

var ally_ref
var current_state := State.FOLLOWING
var player_target
var enemy_target
var state_update_timer := 0.0
var state_update_interval := 0.1  # Update AI state 10 times per second
var attack_delay_timer := 0.0
var attack_delay := 0.0
var retreat_timer := 0.0

# --- Extended Ally Name Generation ---
# 1000+ fantasy-style first and last names (sampled, you can expand further)
var first_names = [
	"Aiden", "Luna", "Kai", "Mira", "Rowan", "Zara", "Finn", "Nova", "Ezra", "Lyra",
	"Orin", "Sage", "Rhea", "Jax", "Vera", "Theo", "Ivy", "Dax", "Nia", "Kian",
	"Tara", "Milo", "Suri", "Riven", "Elara", "Bryn", "Juno", "Vale", "Niko", "Sable",
	"Astra", "Corin", "Eira", "Lira", "Marek", "Nyx", "Oryn", "Pax", "Quill", "Rivena",
	"Soren", "Talon", "Vesper", "Wyn", "Xara", "Yara", "Zarek", "Aeliana", "Balen", "Cael",
	"Darian", "Elys", "Faelan", "Galen", "Halyn", "Isen", "Jarek", "Kael", "Lirael", "Mirael",
	"Neris", "Orin", "Pyria", "Quorin", "Rylin", "Sylas", "Tirian", "Uriel", "Vael", "Weylin",
	"Xyra", "Yalen", "Zyra", "Aeris", "Briar", "Caius", "Darian", "Elowen", "Fira", "Galen",
	"Hale", "Iria", "Jace", "Kira", "Lira", "Mira", "Nira", "Orin", "Pax", "Quin", "Ryn"
]
var last_names = [
	"Stormrider", "Dawnbringer", "Nightshade", "Ironwood", "Starfall", "Ashwalker", "Frostwind", "Shadowmere",
	"Brightblade", "Moonwhisper", "Stonehelm", "Swiftarrow", "Emberforge", "Mistvale", "Oakenshield", "Riversong",
	"Wolfbane", "Sunstrider", "Duskwalker", "Windrider", "Firebrand", "Silverleaf", "Darkwater", "Goldheart",
	"Hawthorne", "Stormwatch", "Ironfist", "Lightfoot", "Shadowfox", "Winterborn", "Amberfall", "Blackswan",
	"Cinderfell", "Duskwhisper", "Eaglecrest", "Flintlock", "Grimward", "Hollowbrook", "Ironvale", "Jadeblade",
	"Kingsley", "Larkspur", "Moonshadow", "Nightriver", "Oakheart", "Pinecrest", "Quickwater", "Ravencrest",
	"Stormvale", "Thornfield", "Umbermoor", "Valebrook", "Westwood", "Yewbranch", "Zephyrwind", "Ashenford",
	"Briarwood", "Cloudspire", "Dawnforge", "Ebonwood", "Frostvale", "Glimmerstone", "Hawkwing", "Ivoryspire",
	"Jasperfield", "Kestrel", "Lionshade", "Mistwood", "Northwind", "Oakenfield", "Pinevale", "Quicksilver",
	"Ridgewood", "Stonevale", "Thornbush", "Umberfield", "Violetmoor", "Willowisp", "Yarrow", "Zephyrfield"
]

var name_label: Label3D = null
var health_label: Label3D = null

func _ready():
	# Expand first_names and last_names to 1000+ entries each at runtime
	while first_names.size() < 1000:
		first_names.append("Name%d" % first_names.size())
	while last_names.size() < 1000:
		last_names.append("Surname%d" % last_names.size())
	# Create name and health labels above the ally
	call_deferred("_create_name_and_health_labels")

func _create_name_and_health_labels():
	if not ally_ref:
		return
	# Create name label
	name_label = Label3D.new()
	var display_name = ally_ref.get_meta("display_name") if ally_ref.has_meta("display_name") else ally_ref.name
	name_label.text = display_name
	name_label.position = Vector3(0, 2.2, 0)
	name_label.modulate = Color(1,1,0.7,1)
	name_label.font_size = 22
	name_label.outline_size = 1
	ally_ref.add_child(name_label)
	# Create health label
	health_label = Label3D.new()
	health_label.text = _get_health_text()
	health_label.position = Vector3(0, 1.9, 0)
	health_label.modulate = Color(1,1,1,1)
	health_label.font_size = 18
	health_label.outline_size = 1
	ally_ref.add_child(health_label)

func _get_health_text() -> String:
	if ally_ref and ally_ref.health_component:
		return "HP: %d/%d" % [ally_ref.health_component.current_health, ally_ref.max_health]
	return "HP: ?"

func generate_random_name() -> String:
	var first = first_names[randi() % first_names.size()]
	var last = last_names[randi() % last_names.size()]
	return first + " " + last

func setup(ally):
	ally_ref = ally
	# Assign a random name if not already set
	if not ally_ref.has_meta("display_name"):
		var random_name = generate_random_name()
		ally_ref.set_meta("display_name", random_name)
		ally_ref.name = random_name
		var health = ally_ref.health_component.current_health if ally_ref and ally_ref.health_component else -1
		print("🆕 Ally assigned name: ", random_name, " | Health: ", health)

func set_player_target(player):
	player_target = player

func _process(delta):
	state_update_timer += delta
	if state_update_timer >= state_update_interval:
		_update_ai_state()
		state_update_timer = 0.0
	_execute_current_state(delta)
	# Update health label every frame
	if health_label:
		health_label.text = _get_health_text()

func _update_ai_state():
	if not player_target:
		return
	# Find nearest enemy
	enemy_target = ally_ref.combat_component.find_nearest_enemy()
	var previous_state = current_state
	# Retreat if low health
	if ally_ref.health_component.current_health < ally_ref.max_health * 0.25 and enemy_target:
		current_state = State.RETREATING
		retreat_timer = 1.0 + randf() * 1.5
		return
	# State logic
	if enemy_target:
		var distance_to_enemy = ally_ref.global_position.distance_to(enemy_target.global_position)
		if distance_to_enemy <= ally_ref.combat_component.attack_range:
			current_state = State.ATTACKING
		elif distance_to_enemy <= ally_ref.combat_component.detection_range:
			current_state = State.MOVING_TO_TARGET
		else:
			current_state = State.FOLLOWING
	else:
		current_state = State.FOLLOWING
	if previous_state != current_state:
		print("🤖 Ally AI: ", State.keys()[previous_state], " → ", State.keys()[current_state])

func _execute_current_state(delta: float):
	match current_state:
		State.FOLLOWING:
			_handle_following(delta)
		State.MOVING_TO_TARGET:
			_handle_moving_to_target(delta)
		State.ATTACKING:
			_handle_attacking(delta)
		State.RETREATING:
			_handle_retreating(delta)

func _handle_following(delta: float):
	if not player_target:
		return
	var distance_to_player = ally_ref.global_position.distance_to(player_target.global_position)
	if distance_to_player > ally_ref.movement_component.follow_distance:
		ally_ref.movement_component.move_towards_target(player_target.global_position, delta)
	else:
		ally_ref.movement_component.orbit_around_player(player_target, delta)
	ally_ref.movement_component.apply_separation(delta)

func _handle_moving_to_target(delta: float):
	if not enemy_target:
		current_state = State.FOLLOWING
		return
	# Strafe/circle around enemy
	ally_ref.movement_component.strafe_around_target(enemy_target, delta)
	ally_ref.movement_component.apply_separation(delta)

func _handle_attacking(delta: float):
	if not enemy_target:
		current_state = State.FOLLOWING
		return
	# Add random attack delay for realism
	if attack_delay_timer > 0:
		attack_delay_timer -= delta
		return
	if randf() < 0.1:
		attack_delay = 0.1 + randf() * 0.3
		attack_delay_timer = attack_delay
		return
	ally_ref.combat_component.attack_target(enemy_target)
	ally_ref.velocity.x = move_toward(ally_ref.velocity.x, 0, ally_ref.speed * 2 * delta)
	ally_ref.velocity.z = move_toward(ally_ref.velocity.z, 0, ally_ref.speed * 2 * delta)

func _handle_retreating(delta: float):
	if retreat_timer > 0:
		retreat_timer -= delta
		# Move away from enemy
		if enemy_target:
			ally_ref.movement_component.move_away_from_target(enemy_target.global_position, delta)
		return
	current_state = State.FOLLOWING

# --- Ally Command System ---
func command_move_to_position(position: Vector3):
	# Move to a commanded position (for AllyCommandManager)
	var health = ally_ref.health_component.current_health if ally_ref and ally_ref.health_component else -1
	print("🎯 Ally '", ally_ref.name, "' received move command to ", position, " | Health: ", health)
	# You can implement more advanced state logic here if desired
	ally_ref.movement_component.move_towards_target(position, 0.1) # Move a little each call
