extends Area2D
@export var boost_force: float = 500.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		var direction_alignment = body.current_velocity.normalized().dot(transform.x)
		if direction_alignment > 0:
			body.apply_booster_pad(transform.x * boost_force)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
