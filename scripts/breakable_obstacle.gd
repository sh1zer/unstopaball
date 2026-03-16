extends Node2D


var durability = 3

var sprite_full = preload("res://sprites/crate.png")
var sprite_damaged1 = preload("res://sprites/crate2.png")
var sprite_damaged2 = preload("res://sprites/crate3.png")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$StaticBody2D/Sprite2D.texture = sprite_full

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name != 'Player':
		return
	durability -= 1
	if durability <= 0:
		queue_free()
	elif durability == 2:
		$StaticBody2D/Sprite2D.texture = sprite_damaged1
	elif durability == 1:
		$StaticBody2D/Sprite2D.texture = sprite_damaged2
		
