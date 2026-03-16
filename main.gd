extends Node

func new_game():
	$Player.start(Vector2(100,100))

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	new_game()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$HUD.update_speed($Player.current_velocity.length())
	pass
