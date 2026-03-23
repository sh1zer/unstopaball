extends CharacterBody2D

@onready var target: Node2D = null

@export var move_speed: float = 220.0
@export var bottom_margin: float = 42.0
@export var detection_range: float = 900.0
@export var align_speed: float = 8.0
@export var edge_margin: float = 24.0
@export var bullet_scene: PackedScene
@export var shoot_cooldown: float = 0.8
@export var bullet_speed: float = 420.0
@export var bullet_lifetime: float = 2.0
@export var bullets_per_shot: int = 5
@export var spread_angle_deg: float = 50.0
@export var visualize_shot_angles: bool = true
@export var visualization_length: float = 140.0
@export var visualization_duration: float = 0.25
@export var debug_logs: bool = true

var _patrol_dir: float = 1.0
var _shoot_timer: float = 0.0
var _preview_dirs: Array[Vector2] = []
var _last_shot_dirs: Array[Vector2] = []
var _visual_timer: float = 0.0
var _warned_no_bullet_scene: bool = false
var _had_line_of_sight: bool = false

func _ready() -> void:
	target = get_tree().get_first_node_in_group("player") as Node2D
	if bullet_scene == null:
		bullet_scene = load("res://enemy_bullet.tscn") as PackedScene
	if bullet_scene == null and not _warned_no_bullet_scene:
		_warned_no_bullet_scene = true
		push_warning("Enemy bullet scene is missing. Assign bullet_scene in ennemy.tscn.")
	if debug_logs:
		print("[ENEMY] ready target=", target, " bullet_scene_ok=", bullet_scene != null)
	_shoot_timer = shoot_cooldown
	rotation = 0.0


func _acquire_target() -> bool:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D
		if target == null:
			target = get_tree().current_scene.get_node_or_null("Player") as Node2D
	return target != null


func _get_bottom_y() -> float:
	var viewport_h: float = get_viewport_rect().size.y
	return viewport_h - bottom_margin


func _move_bottom_towards_x(target_x: float) -> void:
	var bottom_y: float = _get_bottom_y()
	var x_delta: float = target_x - global_position.x
	var x_speed: float = 0.0

	if abs(x_delta) > 4.0:
		x_speed = sign(x_delta) * move_speed

	var y_error: float = bottom_y - global_position.y
	velocity = Vector2(x_speed, y_error * align_speed)
	move_and_slide()
	rotation = 0.0


func _patrol_bottom() -> void:
	var viewport_w: float = get_viewport_rect().size.x
	if global_position.x <= edge_margin:
		_patrol_dir = 1.0
	elif global_position.x >= viewport_w - edge_margin:
		_patrol_dir = -1.0

	_move_bottom_towards_x(global_position.x + _patrol_dir * 120.0)

	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if abs(collision.get_normal().x) > 0.7:
			_patrol_dir *= -1.0
			break


func _can_see_target() -> bool:
	if global_position.distance_to(target.global_position) > detection_range:
		return false

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [self.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.hit_from_inside = true
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		# If the ray returned no collider, treat target as visible in open space.
		return true

	var collider_obj: Object = result.get("collider", null)
	if collider_obj == null:
		return false

	if collider_obj == target:
		return true

	if collider_obj is Node:
		var collider_node: Node = collider_obj as Node
		if target.is_ancestor_of(collider_node):
			return true

	return false


func _build_shot_directions(base_dir: Vector2) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	var normalized_base: Vector2 = base_dir.normalized()
	var count: int = max(1, bullets_per_shot)

	if count == 1:
		dirs.append(normalized_base)
		return dirs

	var spread: float = max(0.0, spread_angle_deg)
	var start_angle: float = -spread * 0.5
	var step: float = spread / float(count - 1)

	for i in range(count):
		var angle_rad: float = deg_to_rad(start_angle + step * float(i))
		dirs.append(normalized_base.rotated(angle_rad))

	return dirs


func _shoot_at_target() -> void:
	if bullet_scene == null:
		if debug_logs:
			print("[ENEMY] cannot shoot: bullet_scene is null")
		return

	var base_dir: Vector2 = (target.global_position - global_position).normalized()
	var dirs: Array[Vector2] = _build_shot_directions(base_dir)
	_last_shot_dirs = dirs.duplicate()
	_visual_timer = visualization_duration
	if debug_logs:
		print("[ENEMY] shoot volley bullets=", dirs.size(), " from=", global_position, " to=", target.global_position)

	for dir in dirs:
		var bullet: Node2D = bullet_scene.instantiate() as Node2D
		if bullet == null:
			if debug_logs:
				print("[ENEMY] bullet instantiate returned null")
			continue
		bullet.global_position = global_position + dir * 24.0
		if bullet.has_method("setup"):
			bullet.setup(dir, bullet_speed, bullet_lifetime, self)
		else:
			if debug_logs:
				print("[ENEMY] bullet missing setup() method")
		get_tree().current_scene.add_child(bullet)
		if debug_logs:
			print("[ENEMY] spawned bullet at ", bullet.global_position, " dir=", dir)


func _draw() -> void:
	if not visualize_shot_angles:
		return

	for dir in _preview_dirs:
		draw_line(Vector2.ZERO, dir * visualization_length, Color(1.0, 0.84, 0.15, 0.75), 2.0)

	if _visual_timer > 0.0:
		var alpha: float = clamp(_visual_timer / max(0.001, visualization_duration), 0.0, 1.0)
		for dir in _last_shot_dirs:
			draw_line(Vector2.ZERO, dir * (visualization_length + 24.0), Color(1.0, 0.25, 0.2, alpha), 3.0)

func _physics_process(_delta: float) -> void:
	if not _acquire_target():
		velocity = Vector2.ZERO
		_preview_dirs.clear()
		queue_redraw()
		return

	var has_line_of_sight: bool = _can_see_target()
	if has_line_of_sight != _had_line_of_sight and debug_logs:
		print("[ENEMY] line_of_sight=", has_line_of_sight, " dist=", global_position.distance_to(target.global_position))
	_had_line_of_sight = has_line_of_sight

	if has_line_of_sight:
		_move_bottom_towards_x(target.global_position.x)
		_preview_dirs = _build_shot_directions((target.global_position - global_position).normalized())
		_shoot_timer -= _delta
		if _shoot_timer <= 0.0:
			_shoot_at_target()
			_shoot_timer = shoot_cooldown
	else:
		_preview_dirs.clear()
		_patrol_bottom()

	if _visual_timer > 0.0:
		_visual_timer -= _delta

	queue_redraw()
