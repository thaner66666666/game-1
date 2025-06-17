extends CharacterBody3D
class_name Ally

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

var player_ref: CharacterBody3D

func _ready():
    add_to_group("allies")
    _setup_components()
    _find_player()

func _setup_components():
    # Initialize each component with needed references
    health_component.setup(self, max_health)
    movement_component.setup(self, speed)
    combat_component.setup(self, attack_damage, detection_range)
    ai_component.setup(self)

func _find_player():
    player_ref = get_tree().get_first_node_in_group("player")
    if player_ref:
        ai_component.set_player_target(player_ref)

func _physics_process(delta):
    # Let AI component handle movement decisions
    # Movement component will set velocity
    # Apply separation
    movement_component.apply_separation(delta)
    
    # Apply gravity
    if not is_on_floor():
        velocity.y -= 9.8 * delta
    else:
        velocity.y = 0
    
    # Move the character
    move_and_slide()

func take_damage(amount: int, attacker: Node = null):
    health_component.take_damage(amount, attacker)

func _on_ally_died():
    print("💀 Ally died!")
    # Disable collision and hide
    collision_layer = 0
    collision_mask = 0
    mesh_instance.visible = false
    
    # Clean up after delay
    get_tree().create_timer(1.0).timeout.connect(queue_free)
