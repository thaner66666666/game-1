extends Area2D

# Declare member variables here. Examples:
var speed = 400
var damage = 10
var range = 100
var cooldown = 1.0
var lifetime = 5.0
var wrap_value = true setget set_wrap, get_wrap
var texture : Texture

onready var sprite = $Sprite
onready var collision_shape = $CollisionShape2D

# Called when the node enters the scene tree for the first time.
func _ready():
	if texture:
		sprite.texture = texture
	if wrap_value:
		set_process(true)
	else:
		set_process(false)

func set_wrap(value):
	wrap_value = value
	set_process(value)

func get_wrap():
	return wrap_value

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if wrap_value:
		position.x += speed * delta
		if position.x > get_viewport().size.x:
			position.x = 0
		elif position.x < 0:
			position.x = get_viewport().size.x
		position.y += speed * delta
		if position.y > get_viewport().size.y:
			position.y = 0
		elif position.y < 0:
			position.y = get_viewport().size.y

func _on_Timer_timeout():
	queue_free()

func _on_Area2D_body_entered(body):
	if body.is_in_group("enemies"):
		body.apply_damage(damage)
		queue_free()

func _input(_event):
	pass