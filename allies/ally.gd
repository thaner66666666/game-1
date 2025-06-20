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
# Simple body animation variables
var body_node
var body_original_pos: Vector3
var body_waddle_time: float = 0.0

var player_ref: CharacterBody3D

# Default ally color for flash restorataion
const DEFAULT_ALLY_COLOR = Color(0.9, 0.7, 0.6)  # Default skin tone

func _ready():
	add_to_group("allies")
	_setup_components()
	_ensure_hands_visible()
	_find_player()
	# Connect health component death signal
	if health_component:
		health_component.health_depleted.connect(_on_health_depleted)
	# Initialize body animation after movement setup
	if movement_component:
		movement_component.initialize_body_animation()
	# Connect collision for taking damage from enemies
	if has_node("CollisionShape3D"):
		$CollisionShape3D.connect("body_entered", Callable(self, "_on_body_entered"))

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
	# Generate random character appearance with varied skin tones
	var config = CharacterGenerator.generate_random_character_config()
	# Don't override skin_tone - let it use the random one from generate_random_character_config()
	CharacterAppearanceManager.create_player_appearance(self, config)
	print("🎨 Created ally with skin tone: ", config["skin_tone"])


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
	# Find body node (MeshInstance3D with 'Body' in name)
	body_node = null
	var mesh_children = []
	for child in get_children():
		if child is MeshInstance3D:
			mesh_children.append(child)
	print("🔍 MeshInstance3D children:", mesh_children.map(func(c): return c.name))
	# Try to find by 'Body', 'Torso', 'Chest'
	# Use 'body_name' to avoid shadowing base class property
	for body_name in ["Body", "Torso", "Chest"]:
		for child in mesh_children:
			if body_name in child.name:
				body_node = child
				body_original_pos = body_node.position
				print("✅ Found body node by name '", body_name, "': ", body_node.name, " at ", body_original_pos)
				break
		if body_node:
			break
	# Fallback: use mesh_instance or first MeshInstance3D
	if not body_node:
		if mesh_instance:
			body_node = mesh_instance
			body_original_pos = body_node.position
			print("⚠️ Fallback: using mesh_instance as body_node: ", body_node.name, " at ", body_original_pos)
		elif mesh_children.size() > 0:
			body_node = mesh_children[0]
			body_original_pos = body_node.position
			print("⚠️ Fallback: using first MeshInstance3D as body_node: ", body_node.name, " at ", body_original_pos)
	if not body_node:
		print("❌ Could not find body node")

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
	# Very subtle sway and bob (no idle reset)
	if body_node and velocity.length() > 0.1:
		body_waddle_time += delta * 5.0
		var sway = sin(body_waddle_time) * 0.025  # Very subtle left-right movement
		var bob = sin(body_waddle_time * 2.0) * 0.06  # Very subtle up-down bobbing
		var forward_lean = sin(body_waddle_time * 0.5) * 0.01  # Minimal lean
		body_node.position = body_original_pos + Vector3(sway, bob, forward_lean)

func take_damage(amount: int, _source = null):
	if get_tree().get_first_node_in_group("damage_numbers"):
		# Show red numbers for ally damage
		get_tree().get_first_node_in_group("damage_numbers").show_damage(amount, self, "massive")
	_flash_red()
	# ...existing health/damage logic here...



	if get_tree().get_first_node_in_group("damage_numbers"):
		get_tree().get_first_node_in_group("damage_numbers").show_damage(amount, self, "normal")
	_flash_red()
	# ...existing health/damage logic here...


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

# Flash the ally red briefly when taking damage
func _flash_red():
	if not mesh_instance or not is_instance_valid(mesh_instance):
		return
	if not mesh_instance.material_override:
		return
	mesh_instance.material_override.albedo_color = Color(1,0,0)
	# Use modern Godot 4.1 approach with create_timer
	get_tree().create_timer(0.5).timeout.connect(func():
		if mesh_instance and is_instance_valid(mesh_instance) and mesh_instance.material_override:
			mesh_instance.material_override.albedo_color = DEFAULT_ALLY_COLOR
	)


func _on_body_entered(body):
	if body.is_in_group("enemies"):
		# Use MCP server or local logic to apply damage
		if has_node("/root/MCPServer"):
			# Example: send a message to MCP server (pseudo-code, adapt as needed)
			var mcp = get_node("/root/MCPServer")
			mcp.request_ally_take_damage(self, body.attack_damage)
		else:
			take_damage(body.attack_damage, body)
