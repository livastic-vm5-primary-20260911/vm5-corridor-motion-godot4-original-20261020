extends Node3D
## Standalone original PSX-like room, NOT an external client's Backrooms assets.
const PLAYER_SCRIPT := preload("res://player.gd")
var player: CharacterBody3D
var status: Label
var stamina_bar: ProgressBar

func _ready() -> void:
	_make_environment()
	_make_geometry()
	_make_player()
	_make_interface()

func _make_environment() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#10121a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fa4cb")
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	light.light_color = Color("#d2d8ff")
	light.light_energy = 1.3
	add_child(light)

func _block(label: String, location: Vector3, dimensions: Vector3, tint: Color) -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.name = label
	wall.position = location
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = dimensions
	shape.shape = box
	wall.add_child(shape)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	visual.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.06
	material.roughness = 0.92
	visual.material_override = material
	wall.add_child(visual)
	add_child(wall)

func _make_geometry() -> void:
	_block("CollisionFloor", Vector3(0.0, -0.30, 0.0), Vector3(22.0, 0.60, 22.0), Color("#313d51"))
	_block("NorthWall", Vector3(0.0, 2.0, -11.0), Vector3(22.0, 4.0, 0.60), Color("#556073"))
	_block("SouthWall", Vector3(0.0, 2.0, 11.0), Vector3(22.0, 4.0, 0.60), Color("#556073"))
	_block("WestWall", Vector3(-11.0, 2.0, 0.0), Vector3(0.60, 4.0, 22.0), Color("#414b62"))
	_block("EastWall", Vector3(11.0, 2.0, 0.0), Vector3(0.60, 4.0, 22.0), Color("#414b62"))
	_block("CenterPier", Vector3(0.0, 1.15, -3.0), Vector3(2.8, 2.3, 2.8), Color("#9a7588"))
	_block("LeftPier", Vector3(-6.0, 1.25, 0.0), Vector3(1.6, 2.5, 2.1), Color("#76959a"))
	_block("RightPier", Vector3(6.0, 1.25, 1.0), Vector3(1.6, 2.5, 2.1), Color("#76959a"))
	_block("BackWallA", Vector3(-5.0, 1.35, -7.0), Vector3(5.0, 2.7, 0.5), Color("#514d74"))
	_block("BackWallB", Vector3(6.0, 1.35, -7.0), Vector3(6.0, 2.7, 0.5), Color("#514d74"))
	for i: int in range(7):
		_block("FloorStripe%02d" % i, Vector3(-9.0 + float(i)*3.0, 0.008, 7.0), Vector3(0.15, 0.015, 6.0), Color("#7b8caa"))

func _make_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(0.0, 1.05, 5.0)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.75
	shape.shape = capsule
	player.add_child(shape)
	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position.y = 0.38
	player.add_child(head)
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 76.0
	camera.current = true
	head.add_child(camera)
	add_child(player)

func _make_interface() -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	ui.name = "HUD"
	add_child(ui)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var top: PanelContainer = PanelContainer.new()
	top.offset_left = 16.0
	top.offset_top = 16.0
	top.offset_right = 530.0
	top.offset_bottom = 132.0
	root.add_child(top)
	var box: VBoxContainer = VBoxContainer.new()
	top.add_child(box)
	var nameplate: Label = Label.new()
	nameplate.text = "CORRIDOR MOTION LAB  •  GODOT 4"
	box.add_child(nameplate)
	var instructions: Label = Label.new()
	instructions.text = "WASD / ARROWS: move   SHIFT: sprint   MOUSE: look"
	box.add_child(instructions)
	var controls: Label = Label.new()
	controls.text = "Click to capture pointer   ESC: release   R: reset"
	box.add_child(controls)
	status = Label.new()
	status.text = "Stamina 100% | WALK"
	box.add_child(status)
	stamina_bar = ProgressBar.new()
	stamina_bar.max_value = 100.0
	stamina_bar.value = 100.0
	stamina_bar.show_percentage = false
	box.add_child(stamina_bar)
	var cross: Label = Label.new()
	cross.text = "+"
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.add_theme_font_size_override("font_size", 24)
	root.add_child(cross)
	player.stamina_changed.connect(_update_stamina)
	player.sprinting_changed.connect(_update_sprint)

func _update_stamina(value: float, maximum: float) -> void:
	if stamina_bar == null:
		return
	stamina_bar.value = 100.0 * value / maxf(maximum, 0.01)
	status.text = "Stamina %d%% | %s" % [roundi(100.0 * value / maxf(maximum, 0.01)), "SPRINT" if player.sprinting else "WALK"]

func _update_sprint(_enabled: bool) -> void:
	_update_stamina(player.stamina, player.STAMINA_MAX)
