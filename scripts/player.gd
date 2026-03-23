extends CharacterBody2D
class_name Player
@export var initial_speed: float = 5.0
@export var max_speed: float = 500.0
@export var boost_strength: float = 200.0

var current_velocity: Vector2 = Vector2.ZERO

# Grapple state
var grapple_active: bool = false
var grapple_anchor: Vector2 = Vector2.ZERO
var rope_length: float = 0.0

# Experimental: grapple speed boost
@export var grapple_boost_enabled: bool = true
@export var grapple_boost_multiplier: float = 1.02
@export var grapple_boost_duration: float = 0.5
@export var grapple_max_length: float = 500.0
var _grapple_boost_timer: float = 0.0

# Audio players
@onready var collision_player: AudioStreamPlayer2D = $SoundPlayers/CollisionPlayer
@onready var booster_pad_player: AudioStreamPlayer2D = $SoundPlayers/BoosterPadPlayer
@onready var boost_player: AudioStreamPlayer2D = $SoundPlayers/BoostPlayer


func start(pos: Vector2) -> void:
	position = pos
	show()
	$PlayerCollision.disabled = false


func _ready() -> void:
	add_to_group("player")
	current_velocity = Vector2(1, -1).normalized() * initial_speed
	$Rope.add_point(Vector2.ZERO)
	$Rope.add_point(Vector2.ZERO)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fire") and not grapple_active:
		_handle_grapple()
	elif event.is_action_released("fire"):
		grapple_active = false

	if event.is_action_pressed("boost"):
		_handle_boost()


func _handle_boost() -> void:
	var direction := (get_global_mouse_position() - global_position).normalized()
	if current_velocity.length() > 250:
		current_velocity = direction * (current_velocity.length() + 100) * 0.7
	else:
		current_velocity = direction * 250
	current_velocity = current_velocity.limit_length(max_speed)
	boost_player.play()
	var poof: AnimatedSprite2D = $BoostPoof.duplicate()
	get_tree().current_scene.add_child(poof)
	poof.global_position = global_position - direction * 20.0
	poof.animation_finished.connect(poof.queue_free)
	poof.show()
	poof.play("poof")

func _handle_grapple() -> void:
	var space = get_world_2d().direct_space_state
	var mouse_pos := get_global_mouse_position()
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collision_mask = 2
	var results = space.intersect_point(query)
	if results.size() > 0 and (mouse_pos - position).length() < grapple_max_length:
		var result = results[0]
		grapple_active = true
		grapple_anchor = result.collider.global_position
		rope_length = global_position.distance_to(grapple_anchor)
		if grapple_boost_enabled:
			_grapple_boost_timer = grapple_boost_duration


func _process(_delta: float) -> void:
	$Rope.visible = grapple_active
	if grapple_active:
		$Rope.set_point_position(0, Vector2.ZERO)
		$Rope.set_point_position(1, to_local(grapple_anchor))


func _physics_process(delta: float) -> void:
	_process_movement(delta)
	if grapple_active:
		_process_grapple()
	look_at(get_global_mouse_position())


func _process_grapple() -> void:
	var to_player := global_position - grapple_anchor
	if to_player.length() >= rope_length:
		var rope_dir := to_player.normalized()
		var radial := current_velocity.dot(rope_dir)
		if radial > 0.0:
			current_velocity -= rope_dir * radial
		global_position = grapple_anchor + rope_dir * rope_length


func _process_movement(delta: float) -> void:
	# Experimental: grapple speed boost
	if grapple_boost_enabled and _grapple_boost_timer > 0.0:
		_grapple_boost_timer -= delta
		current_velocity *= grapple_boost_multiplier
		current_velocity = current_velocity.limit_length(max_speed)

	var collision_data = move_and_collide(current_velocity * delta)
	if collision_data:
		collision_player.play()
		var collision_normal = collision_data.get_normal()
		current_velocity = current_velocity.bounce(collision_normal)
		current_velocity = current_velocity.limit_length(max_speed)
		var remainder = collision_data.get_remainder()
		move_and_collide(remainder.bounce(collision_normal))

func apply_booster_pad(boost_force: Vector2):
	booster_pad_player.play()
	current_velocity += boost_force
	current_velocity = current_velocity.limit_length(max_speed)

func _on_boost_poof_animation_finished() -> void:
	pass
