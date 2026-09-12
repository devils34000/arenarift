class_name ArenaPlayer
extends CharacterBody2D

signal spell_cast(kind: String, origin: Vector2, direction: Vector2, caster: CharacterBody2D)

const SPEED := 540.0
const DASH_SPEED := 1450.0
const DASH_TIME := 0.12

var max_health := 100
var health := 100
var team_color := Color("48a9ff")
var is_bot := false
var target: CharacterBody2D
var dash_left := 0.0
var dash_cooldown := 0.0
var orb_cooldown := 0.0
var nova_cooldown := 0.0
var recoil := Vector2.ZERO
var flash_time := 0.0


func _ready() -> void:
	add_to_group("fighters")
	queue_redraw()


func _physics_process(delta: float) -> void:
	flash_time = maxf(0.0, flash_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	orb_cooldown = maxf(0.0, orb_cooldown - delta)
	nova_cooldown = maxf(0.0, nova_cooldown - delta)

	if is_bot:
		_bot_input(delta)
	else:
		_player_input()

	if dash_left > 0.0:
		dash_left -= delta
		velocity = velocity.normalized() * DASH_SPEED
	else:
		velocity = velocity.limit_length(SPEED)

	velocity += recoil
	recoil = recoil.move_toward(Vector2.ZERO, 2800.0 * delta)

	move_and_slide()

	position.x = clampf(position.x, 42.0, 2158.0)
	position.y = clampf(position.y, 42.0, 1358.0)

	queue_redraw()


func _player_input() -> void:
	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = input_direction * SPEED
	look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("spell_dash"):
		try_dash(input_direction)

	if Input.is_action_just_pressed("spell_orb"):
		try_orb((get_global_mouse_position() - global_position).normalized())

	if Input.is_action_just_pressed("spell_nova"):
		try_nova()


func _bot_input(_delta: float) -> void:
	if not is_instance_valid(target):
		return

	var to_target := target.global_position - global_position
	var distance := to_target.length()

	var strafe := Vector2(
		-to_target.y,
		to_target.x
	).normalized() * sin(Time.get_ticks_msec() * 0.004)

	velocity = (
		to_target.normalized() * (1.0 if distance > 440.0 else -0.45)
		+ strafe * 0.65
	).normalized() * SPEED * 0.65

	look_at(target.global_position)

	if distance < 850.0 and orb_cooldown <= 0.0:
		try_orb(to_target.normalized())

	if distance < 190.0 and nova_cooldown <= 0.0:
		try_nova()


func try_dash(direction: Vector2) -> void:
	if dash_cooldown > 0.0:
		return

	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(rotation)

	velocity = direction.normalized() * DASH_SPEED
	dash_left = DASH_TIME
	dash_cooldown = 1.3


func try_orb(direction: Vector2) -> void:
	if orb_cooldown > 0.0 or direction == Vector2.ZERO:
		return

	orb_cooldown = 0.48

	spell_cast.emit(
		"orb",
		global_position + direction * 38.0,
		direction,
		self
	)


func try_nova() -> void:
	if nova_cooldown > 0.0:
		return

	nova_cooldown = 4.0

	spell_cast.emit(
		"nova",
		global_position,
		Vector2.ZERO,
		self
	)


func take_damage(amount: int, force: Vector2) -> void:
	health -= amount
	recoil += force
	flash_time = 0.10

	if health <= 0:
		if not is_bot:
			health = max_health
			position = Vector2(1100, 700)
			return

		health = max_health
		position = Vector2(1100, 700) + Vector2(
			randf_range(-360.0, 360.0),
			randf_range(-220.0, 220.0)
		)


func cooldown_text() -> String:
	return "Orbe %.1fs | Nova %.1fs | Dash %.1fs" % [
		orb_cooldown,
		nova_cooldown,
		dash_cooldown
	]


func _draw() -> void:
	# Personnage procédural animé :
	# aucune image collée, la pose suit le déplacement.

	var speed_ratio := clampf(
		velocity.length() / SPEED,
		0.0,
		1.0
	)

	var walk_phase := Time.get_ticks_msec() * 0.014 * (0.25 + speed_ratio)
	var stride := sin(walk_phase) * 10.0 * speed_ratio
	var bob: float = absf(sin(walk_phase)) * 2.5 * speed_ratio

	var body_color := team_color.lightened(0.16)
	var dark_color := team_color.darkened(0.52)

	if flash_time > 0.0:
		body_color = Color("fff5f7")

	# Ombre, anneau d'équipe et deux jambes alternées.
	draw_my_ellipse(
		Vector2(0, 24),
		Vector2(30, 11),
		Color("050914", 0.60)
	)

	draw_arc(
		Vector2(0, 13),
		33.0,
		0.0,
		TAU,
		32,
		Color(team_color, 0.8),
		2.5
	)

	draw_line(
		Vector2(-9, 11 + bob),
		Vector2(-12 + stride, 29),
		dark_color,
		11.0,
		true
	)

	draw_line(
		Vector2(9, 11 + bob),
		Vector2(12 - stride, 29),
		dark_color,
		11.0,
		true
	)

	# Cape, torse et tête.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-18, -6 + bob),
			Vector2(18, -6 + bob),
			Vector2(27, 23),
			Vector2(-23, 23)
		]),
		dark_color
	)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-15, -23 + bob),
			Vector2(16, -23 + bob),
			Vector2(20, 11 + bob),
			Vector2(-17, 11 + bob)
		]),
		body_color
	)

	draw_circle(
		Vector2(0, -35 + bob),
		13.0,
		Color("f2d2bd")
	)

	draw_circle(
		Vector2(4, -37 + bob),
		3.2,
		Color("d8f7ff")
	)

	# Bras et lame :
	# ils suivent naturellement la direction de visée du personnage.
	draw_line(
		Vector2(12, -13 + bob),
		Vector2(26, -3 - stride * 0.25 + bob),
		body_color,
		9.0,
		true
	)

	draw_line(
		Vector2(26, -3 - stride * 0.25 + bob),
		Vector2(39, -18 + bob),
		Color("e8f4ff"),
		5.0,
		true
	)

	draw_line(
		Vector2(38, -19 + bob),
		Vector2(68, -47 + bob),
		Color("8eeeff"),
		5.0,
		true
	)

	draw_circle(
		Vector2(68, -47 + bob),
		5.0,
		Color("e5ffff")
	)

	draw_line(
		Vector2(-12, -13 + bob),
		Vector2(-25, -4 + stride * 0.25 + bob),
		body_color.darkened(0.12),
		9.0,
		true
	)

	# Barre de vie circulaire.
	draw_arc(
		Vector2.ZERO,
		33.0,
		-PI * 0.5,
		-PI * 0.5 + TAU * (float(health) / max_health),
		32,
		Color("70f3a0"),
		4.0
	)


# Ellipse personnalisée.
# Renommée pour éviter le conflit avec CanvasItem.draw_ellipse()
# de Godot 4.7.
func draw_my_ellipse(
	center: Vector2,
	radii: Vector2,
	color: Color
) -> void:
	var points := PackedVector2Array()

	for i in 20:
		var angle := TAU * float(i) / 20.0

		points.append(
			center + Vector2(
				cos(angle) * radii.x,
				sin(angle) * radii.y
			)
		)

	draw_colored_polygon(points, color)
