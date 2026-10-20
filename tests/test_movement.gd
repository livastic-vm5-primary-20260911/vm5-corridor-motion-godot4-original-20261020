extends SceneTree
## Deterministic Godot runtime QA for original, client-independent FPS sample.

var checks: int = 0
var failed: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS %02d %s" % [checks, description])
	else:
		failed += 1
		printerr("FAIL %02d %s" % [checks, description])

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	check(scene != null, "Original Godot4 project has a real parseable main PackedScene")
	if scene == null:
		quit(1)
		return
	var arena: Node3D = scene.instantiate()
	get_root().add_child(arena)
	for _i in range(6):
		await physics_frame
	var p: CharacterBody3D = arena.get_node_or_null("Player")
	check(p != null, "A CharacterBody3D player was instantiated")
	if p == null:
		quit(1)
		return
	check(p.has_method("simulate_stamina"), "Real loaded character script exposes a reusable stamina method")
	check(p.get_node_or_null("CollisionShape3D") != null, "Player has a working capsule collision shape")
	check(p.get_node_or_null("Head/Camera3D") is Camera3D, "First-person camera is parented to pitch/head pivot")
	var original: Vector3 = p.global_position
	check(original.y > 0.85, "Player spawns above collidable geometry")
	check(InputMap.has_action("move_forward") and InputMap.has_action("move_back") and InputMap.has_action("move_left") and InputMap.has_action("move_right") and InputMap.has_action("sprint"), "Real WASD/arrows and sprint InputMap actions are registered")
	var events: Array[InputEvent] = InputMap.action_get_events("move_forward")
	var has_w: bool = false
	for event in events:
		if event is InputEventKey and event.physical_keycode == KEY_W:
			has_w = true
	check(has_w, "W physical key is mapped to forward control")
	var before: float = float(p.get("stamina"))
	var allowed: bool = bool(p.call("simulate_stamina",true,true,1.0))
	var after: float = float(p.get("stamina"))
	check(allowed and after < before and after > 0.0, "A true moving sprint drains bounded stamina")
	var denied: bool = bool(p.call("simulate_stamina",true,false,0.5))
	check(not denied and float(p.get("stamina")) > after, "Standing still does not sprint and recovers stamina")
	p.set("stamina",0.01)
	check(not bool(p.call("simulate_stamina",true,true,0.04)), "Near-empty stamina correctly prevents further sprint")
	p.set("stamina",5.0)
	var changed: bool = bool(p.call("simulate_stamina",true,true,-1.0))
	check(not changed and is_equal_approx(float(p.get("stamina")),5.0), "Invalid negative physics delta fails closed without changing stamina")
	p.call("set_capture",true)
	p.call("apply_mouse_motion",Vector2(3500.0,3500.0))
	var head: Node3D = p.get_node("Head")
	check(absf(head.rotation.x) <= 1.261, "Camera pitch is clamped to a safe first-person angle")
	check(absf(p.rotation.y)>0.10, "Mouse motion produces a genuine first-person yaw")
	p.call("set_capture",false)
	var yaw_before: float = p.rotation.y
	p.call("apply_mouse_motion",Vector2(20.0,0.0))
	check(is_equal_approx(yaw_before,p.rotation.y), "Pointer release prevents hidden extra mouse-look motion")
	p.call("reset_to_spawn")
	check(p.global_position.distance_to(p.get("start_position")) < 0.001 and is_equal_approx(float(p.get("stamina")),5.0), "R-reset contract restores actual configured spawn and full stamina")
	check(absf(head.rotation.x)<0.001 and absf(p.rotation.y)<0.001, "Reset clears camera pitch and player yaw")
	var count: int = 0
	for child in arena.get_children():
		if child is StaticBody3D:
			count += 1
	check(count >= 10, "Real Godot room creates collidable floor/walls/pillars (not flat fake UI)")
	check(arena.get_node_or_null("HUD") is CanvasLayer, "Actual on-screen stamina and movement overlay exists")
	# Real physics integration: a press is consumed by the engine at 60Hz.
	Input.action_press("move_forward")
	var z_initial: float = p.global_position.z
	for _i in range(45):
		await physics_frame
	Input.action_release("move_forward")
	check(p.global_position.z < z_initial - 0.8, "Genuine Godot 3D physics moves forward on a held action")
	check(p.global_position.y >= 0.84, "Player capsule stays above physical floor")
	p.call("reset_to_spawn")
	var slow_start: float = p.global_position.z
	Input.action_press("move_forward")
	for _i in range(24):
		await physics_frame
	Input.action_release("move_forward")
	var slow_distance: float = slow_start - p.global_position.z
	p.call("reset_to_spawn")
	var fast_start: float = p.global_position.z
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for _i in range(24):
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var fast_distance: float = fast_start - p.global_position.z
	check(fast_distance > slow_distance + 0.30, "Actual engine sprint is faster than walking over the same physics frames")
	check(float(p.get("stamina")) < 5.0, "Actual physics sprint consumes stamina")
	p.call("reset_to_spawn")
	check(absf(p.global_position.z-original.z)<0.001, "Reset returns engine player to exact independent start position")
	print("GODOT_RUNTIME_RESULT "+str(checks-failed)+"/"+str(checks)+" passed; independent sample NOT a paid client or a production integration.")
	arena.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
