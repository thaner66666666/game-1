extends CharacterBody3D
class_name Ally
signal ally_died

# Main ally controller that coordinates all components
# Export stats for easy tweaking in editor
@export_group("Ally Stats")
@export var max_health := 80
@export var speed := 3.5
@export var attack_damage := 20
@export var detection_range := 8.0

# Component references
@onready var health_component: AllyHealth = $HealthComponent
@onready var movement_component: AllyMovement = $MovementComponent
@onready var combat_component: AllyCombat = $CombatComponent
@onready var ai_component: AllyAI = $AIComponent

# Visual references
@onready var mesh_instance := $MeshInstance3D
@onready var left_hand_anchor := $LeftHandAnchor
@onready var right_hand_anchor := $RightHandAnchor

# Foot animation references - no strict typing to avoid crashes
var left_foot
var right_foot
var left_foot_original_pos: Vector3
var right_foot_original_pos: Vector3
var animation_time: float = 0.0

var player_ref: CharacterBody3D

func _ready():
	add_to_group("allies")
	_setup_components()
	_ensure_hands_visible()
	_find_player()
	# Connect health component death signal
	if health_component:
		health_component.health_depleted.connect(_on_health_depleted)

# Use 'await' instead of 'yield' for Godot 4.x compatibility
func _setup_components() -> void:
	# Initialize each component with needed references
	health_component.setup(self, max_health)
	movement_component.setup(self, speed)
	combat_component.setup(self, attack_damage, detection_range)
	ai_component.setup(self)
	health_component.ally_died.connect(_on_ally_died)
	_create_character_appearance()
	# Setup foot references after character appearance is created
	await _setup_foot_references()
	# Make hands visible by default
	_ensure_hands_visible()
	# Configure collision layers for separation
	collision_layer = 8
	collision_mask = 3 | 8

func _create_character_appearance():
	# Generate random character appearance
	var config = CharacterGenerator.generate_random_character_config()
	config["skin_tone"] = Color(0.7, 0.8, 1.0)  # Blue tint for allies
	CharacterAppearanceManager.create_player_appearance(self, config)
	
func _setup_foot_references() -> void:
	# Wait multiple frames to ensure nodes are fully created
	await get_tree().process_frame
	await get_tree().process_frame

	print("🦶 Debugging foot search for ally...")
	print("🔍 Ally children: ", get_children().map(func(child): return child.name))

	# Look for feet by name (they might have numbers appended like LeftFoot2, RightFoot2)
	left_foot = get_node_or_null("LeftFoot")
	right_foot = get_node_or_null("RightFoot")
	
	# If not found, look for numbered versions
	if not left_foot:
		for child in get_children():
			if child is MeshInstance3D and child.name.begins_with("LeftFoot"):
				left_foot = child
				break
	
	if not right_foot:
		for child in get_children():
			if child is MeshInstance3D and child.name.begins_with("RightFoot"):
				right_foot = child
				break

	if left_foot and right_foot:
		left_foot_original_pos = left_foot.position
		right_foot_original_pos = right_foot.position
		print("✅ Found ally feet! LeftFoot: ", left_foot.name, " at ", left_foot.position)
		print("✅ Found ally feet! RightFoot: ", right_foot.name, " at ", right_foot.position)
	else:
		print("❌ Could not find both feet")
		if left_foot:
			print("   - Found LeftFoot: ", left_foot.name)
		if right_foot:
			print("   - Found RightFoot: ", right_foot.name)

func _find_player():
	player_ref = get_tree().get_first_node_in_group("player")
	if player_ref:
		ai_component.set_player_target(player_ref)

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	# Apply movement
	move_and_slide()
	# Animate feet based on movement (with safety checks)
	animation_time += delta
	if left_foot and right_foot and left_foot is MeshInstance3D and right_foot is MeshInstance3D:
		CharacterAppearanceManager.animate_feet_walk(
			left_foot, right_foot, 
			left_foot_original_pos, right_foot_original_pos,
			animation_time, velocity, delta
		)
	elif animation_time > 1.0:  # Only try to find feet after 1 second
		# Try to find feet again if they weren't found initially
		if not left_foot:
			left_foot = get_node_or_null("LeftFoot")
			if left_foot and left_foot is MeshInstance3D:
				left_foot_original_pos = left_foot.position
				print("🦶 Found LeftFoot late!")
		if not right_foot:
			right_foot = get_node_or_null("RightFoot")
			if right_foot and right_foot is MeshInstance3D:
				right_foot_original_pos = right_foot.position
				print("🦶 Found RightFoot late!")

func take_damage(amount: int, attacker: Node = null):
	health_component.take_damage(amount, attacker)

func _on_health_depleted():
	ally_died.emit()

func _on_ally_died():
	print("💀 Ally died!")
	# Disable collision and hide
	collision_layer = 0
	collision_mask = 0
	mesh_instance.visible = false
	
	# Clean up after delay
	get_tree().create_timer(1.0).timeout.connect(queue_free)

# Helper to ensure hands are always visible
func _ensure_hands_visible():
	# Make sure ally hands are visible
	var left_hand = left_hand_anchor.get_node_or_null("LeftHand")
	var right_hand = right_hand_anchor.get_node_or_null("RightHand")
	
	if left_hand:
		left_hand.visible = true
		print("👋 Made LeftHand visible for ally")
	else:
		print("⚠️ LeftHand not found for ally")
	
	if right_hand:
		right_hand.visible = true
		print("👋 Made RightHand visible for ally")
	else:
		print("⚠️ RightHand not found for ally")
