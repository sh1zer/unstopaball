extends Area2D

@export var debug_logs: bool = true

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 2.0
var shooter: Node = null
var _move_log_printed: bool = false


func setup(direction: Vector2, speed: float, life: float, source: Node) -> void:
	velocity = direction.normalized() * speed
	lifetime = life
	shooter = source
	rotation = velocity.angle()
	if debug_logs:
		print("[BULLET] setup pos=", global_position, " vel=", velocity, " life=", lifetime)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Bullets should collide with bodies (walls/player), not other areas/bullets.
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	if debug_logs and not _move_log_printed:
		_move_log_printed = true
		print("[BULLET] moved first frame to=", global_position)
	lifetime -= delta
	if lifetime <= 0.0:
		if debug_logs:
			print("[BULLET] expired")
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if debug_logs:
		print("[BULLET] hit body=", body.name)

	if body.is_in_group("player") and body is CharacterBody2D and "current_velocity" in body:
		body.current_velocity += velocity.normalized() * 120.0

	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area == shooter:
		return
	queue_free()
