extends CharacterBody3D
## Original single-owner VM5 reusable Godot 4 sample: no network or customer code.
signal stamina_changed(current: float, maximum: float)
signal sprinting_changed(active: bool)
const WALK_SPEED := 4.0
const SPRINT_SPEED := 6.8
const STAMINA_MAX := 5.0
const STAMINA_DRAIN := 1.0
const STAMINA_REFILL := 1.4
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := 1.26
const HORIZONTAL_ACCELERATION := 20.0
const GRAVITY := 9.8
var stamina: float = STAMINA_MAX
var sprinting: bool = false
var mouse_captured: bool = false
var controls_enabled: bool = true
var start_position: Vector3
@onready var head: Node3D = $Head

func _ready() -> void:
	start_position = global_position
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	stamina_changed.emit(stamina, STAMINA_MAX)

func set_capture(enable: bool) -> void:
	mouse_captured = enable
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enable else Input.MOUSE_MODE_VISIBLE

func apply_mouse_motion(relative: Vector2) -> void:
	if not mouse_captured or not controls_enabled:
		return
	rotate_y(-relative.x * MOUSE_SENSITIVITY)
	head.rotation.x = clampf(head.rotation.x - relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_capture(true)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			set_capture(false)
		elif event.keycode == KEY_R:
			reset_to_spawn()
	elif event is InputEventMouseMotion:
		apply_mouse_motion(event.relative)

func reset_to_spawn() -> void:
	global_position = start_position
	velocity = Vector3.ZERO
	stamina = STAMINA_MAX
	sprinting = false
	rotation.y = 0.0
	head.rotation.x = 0.0
	stamina_changed.emit(stamina, STAMINA_MAX)
	sprinting_changed.emit(false)

func simulate_stamina(wants_sprint: bool, moving: bool, delta: float) -> bool:
	if delta <= 0.0 or not is_finite(delta):
		return false
	var active: bool = controls_enabled and wants_sprint and moving and stamina > 0.05
	if active:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
	else:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REFILL * delta)
	return active

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		velocity.x = move_toward(velocity.x, 0.0, HORIZONTAL_ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, HORIZONTAL_ACCELERATION * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var direction_2d: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprint_now: bool = simulate_stamina(Input.is_action_pressed("sprint"), direction_2d.length() > 0.10, delta)
	if sprint_now != sprinting:
		sprinting = sprint_now
		sprinting_changed.emit(sprinting)
	stamina_changed.emit(stamina, STAMINA_MAX)
	var wish: Vector3 = global_transform.basis * Vector3(direction_2d.x, 0.0, direction_2d.y)
	wish.y = 0.0
	wish = wish.normalized()
	var speed: float = SPRINT_SPEED if sprint_now else WALK_SPEED
	velocity.x = move_toward(velocity.x, wish.x * speed, HORIZONTAL_ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, wish.z * speed, HORIZONTAL_ACCELERATION * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -0.05
	move_and_slide()
