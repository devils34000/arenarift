extends Node2D

const Player = preload("res://scripts/player_kaykit.gd")
const Projectile = preload("res://scripts/projectile.gd")
const ARENA_SIZE := Vector2(2200, 1400)

var player: CharacterBody2D
var enemies: Array[CharacterBody2D] = []
var projectiles: Array[Area2D] = []
var elapsed := 0.0
var kills := 0
var round_number := 1
var round_time := 90.0
var game_over := false
var wards := [Vector2(820, 510), Vector2(1380, 890), Vector2(1470, 475)]
var objective_position := Vector2(1100, 700)

func _ready() -> void:
	queue_redraw()
	player = Player.new()
	player.position = ARENA_SIZE * 0.5
	player.spell_cast.connect(_on_spell_cast)
	add_child(player)
	var bot_count := 4
	if Network.match_mode == "1V1 DUEL": bot_count = 1
	elif Network.match_mode == "2V2 CLASH": bot_count = 2
	elif Network.match_mode == "3V3 RIVALRY": bot_count = 3
	var spawns := [Vector2(720, 440), Vector2(1510, 390), Vector2(1730, 970), Vector2(580, 1040)]
	for index in bot_count:
		var point: Vector2 = spawns[index]
		var enemy := Player.new()
		enemy.is_bot = true
		enemy.team_color = Color("ff6276")
		enemy.position = point
		enemy.target = player
		enemy.spell_cast.connect(_on_spell_cast)
		add_child(enemy)
		enemies.append(enemy)
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	player.add_child(camera)
	_add_hud()

func _add_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	# Bandeau haut : score, timer et statut de manche.
	var top := _panel(Vector2(364, 18), Vector2(552, 72), Color("111a2ae8"), Color("375b91"), 14)
	top.name = "Top"
	canvas.add_child(top)
	var title := _label("Title", "ARENA RIFT", Vector2(20, 10), Vector2(190, 28), 21, Color("80caff"))
	top.add_child(title)
	var subtitle := _label("Subtitle", "SKIRMISH // RANKED PROTOCOL", Vector2(20, 38), Vector2(210, 18), 11, Color("6c88ae"))
	top.add_child(subtitle)
	var timer := _label("Timer", "01:30", Vector2(244, 12), Vector2(64, 42), 30, Color("fff3c4"), HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(timer)
	var score := _label("Score", "0  —  4", Vector2(342, 16), Vector2(186, 34), 24, Color("f1f6ff"), HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(score)
	# Carte du joueur.
	var player_card := _panel(Vector2(24, 544), Vector2(302, 148), Color("0c1525ef"), Color("315b93"), 16)
	player_card.name = "PlayerCard"
	canvas.add_child(player_card)
	var portrait := _panel(Vector2(16, 18), Vector2(76, 76), Color("1a6fb3"), Color("80d8ff"), 38)
	player_card.add_child(portrait)
	var portrait_image := TextureRect.new()
	portrait_image.texture = load("res://assets/portraits/aeris.png")
	portrait_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_image.position = Vector2(3, 3)
	portrait_image.size = Vector2(70, 70)
	portrait.add_child(portrait_image)
	player_card.add_child(_label("", "AERIS", Vector2(108, 17), Vector2(170, 25), 20, Color("f3f8ff")))
	player_card.add_child(_label("", "ARCANE SKIRMISHER", Vector2(109, 44), Vector2(170, 18), 11, Color("7fa5d1")))
	var health_bar := ProgressBar.new()
	health_bar.name = "Health"
	health_bar.position = Vector2(17, 111)
	health_bar.size = Vector2(267, 14)
	health_bar.max_value = 100
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", _box(Color("172842"), Color("355b8e"), 7, 1))
	health_bar.add_theme_stylebox_override("fill", _box(Color("31d795"), Color("8dffd2"), 7, 0))
	player_card.add_child(health_bar)
	player_card.add_child(_label("HealthText", "100 / 100", Vector2(17, 128), Vector2(267, 16), 12, Color("c8e7db"), HORIZONTAL_ALIGNMENT_CENTER))
	# Cartes de compétences centrales.
	_add_skill_card(canvas, Vector2(390, 594), "LMB", "ARC BOLT", "PROJECTILE • 18 DMG", Color("389eea"), "Orb")
	_add_skill_card(canvas, Vector2(552, 594), "RMB", "NOVA", "ZONE • 22 DMG", Color("b16cf2"), "Nova")
	_add_skill_card(canvas, Vector2(714, 594), "SPACE", "PHASE DASH", "MOBILITÉ", Color("42d6ad"), "Dash")
	# Minimap tactique.
	var mini := _panel(Vector2(1054, 522), Vector2(200, 170), Color("0a1324ef"), Color("315b93"), 14)
	canvas.add_child(mini)
	mini.add_child(_label("", "TACTICAL MAP", Vector2(15, 12), Vector2(170, 18), 11, Color("85b4e8")))
	var map := ColorRect.new()
	map.position = Vector2(15, 39)
	map.size = Vector2(170, 115)
	map.color = Color("152440")
	mini.add_child(map)
	for point in [Vector2(70, 48), Vector2(125, 62), Vector2(145, 90), Vector2(53, 100)]:
		var mark := ColorRect.new()
		mark.position = point
		mark.size = Vector2(7, 7)
		mark.color = Color("ff6478")
		mini.add_child(mark)
	var ally := ColorRect.new()
	ally.position = Vector2(97, 90)
	ally.size = Vector2(8, 8)
	ally.color = Color("66c7ff")
	mini.add_child(ally)

func _add_skill_card(parent: Node, position: Vector2, key: String, skill_name: String, detail: String, color: Color, node_name: String) -> void:
	var card := _panel(position, Vector2(148, 86), Color("0b1425f2"), color.darkened(0.25), 12)
	card.name = node_name
	parent.add_child(card)
	var key_box := _panel(Vector2(10, 10), Vector2(33, 28), color.darkened(0.35), color, 7)
	card.add_child(key_box)
	key_box.add_child(_label("", key, Vector2(0, 5), Vector2(33, 18), 11, Color("ffffff"), HORIZONTAL_ALIGNMENT_CENTER))
	card.add_child(_label("", skill_name, Vector2(52, 11), Vector2(85, 18), 13, Color("f4f8ff")))
	card.add_child(_label("Detail", detail, Vector2(12, 54), Vector2(126, 16), 10, Color("7392bd")))
	card.add_child(_label("Cooldown", "READY", Vector2(92, 34), Vector2(45, 15), 10, color, HORIZONTAL_ALIGNMENT_RIGHT))

func _panel(position: Vector2, size: Vector2, background: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = position
	panel.size = size
	panel.add_theme_stylebox_override("panel", _box(background, border, radius, 1))
	return panel

func _box(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box

func _label(node_name: String, text_value: String, position: Vector2, size: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	if not node_name.is_empty():
		label.name = node_name
	label.text = text_value
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	return label

func _process(delta: float) -> void:
	elapsed += delta
	round_time = maxf(0.0, round_time - delta)
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if fighter.position.distance_to(objective_position) < 82.0:
			fighter.health = mini(fighter.max_health, fighter.health + delta * 9.0)
	var hud := get_node_or_null("HUD") as CanvasLayer
	if hud and player:
		hud.get_node("Top/Timer").text = "%02d:%02d" % [floori(round_time / 60.0), ceili(round_time) % 60]
		hud.get_node("Top/Score").text = "%d  —  %d" % [kills, enemies.size()]
		hud.get_node("Top/Subtitle").text = "%s // ARCANE WELL ACTIVE" % Network.match_mode
		hud.get_node("PlayerCard/Health").value = player.health
		hud.get_node("PlayerCard/HealthText").text = "%d / %d" % [player.health, player.max_health]
		hud.get_node("Orb/Cooldown").text = _ready_text(player.orb_cooldown)
		hud.get_node("Nova/Cooldown").text = _ready_text(player.nova_cooldown)
		hud.get_node("Dash/Cooldown").text = _ready_text(player.dash_cooldown)
	if round_time <= 0.0 and not game_over:
		game_over = true
		_show_round_end()
	queue_redraw()

func _ready_text(cooldown: float) -> String:
	return "PRÊT" if cooldown <= 0.05 else "%.1f s" % cooldown

func _show_round_end() -> void:
	var end_label := Label.new()
	end_label.position = Vector2(410, 310)
	end_label.add_theme_font_size_override("font_size", 38)
	end_label.add_theme_color_override("font_color", Color("fff1b8"))
	end_label.text = "FIN DU ROUND\n%d ÉLIMINATIONS" % kills
	get_node("HUD").add_child(end_label)

func _on_spell_cast(kind: String, origin: Vector2, direction: Vector2, caster: CharacterBody2D) -> void:
	if kind == "orb":
		var orb := Projectile.new()
		orb.position = origin
		orb.velocity = direction * 1050.0
		orb.owner_player = caster
		orb.hit.connect(_on_projectile_hit)
		add_child(orb)
		projectiles.append(orb)
	elif kind == "nova":
		for body in get_tree().get_nodes_in_group("fighters"):
			if body != caster and body.position.distance_to(origin) < 210.0:
				body.take_damage(22, (body.position - origin).normalized() * 520.0)

func _on_projectile_hit(target: CharacterBody2D, orb: Area2D) -> void:
	if target != orb.owner_player:
		if target.is_bot and orb.owner_player == player and target.health - 18 <= 0:
			kills += 1
		target.take_damage(18, orb.velocity.normalized() * 330.0)
	orb.queue_free()

func blocks_projectile(at_position: Vector2) -> bool:
	for ward in wards:
		if ward.distance_to(at_position) < 58.0:
			return true
	return false

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color("111725"), true)
	for x in range(0, int(ARENA_SIZE.x), 100):
		draw_line(Vector2(x, 0), Vector2(x, ARENA_SIZE.y), Color("172137"), 1.0)
	for y in range(0, int(ARENA_SIZE.y), 100):
		draw_line(Vector2(0, y), Vector2(ARENA_SIZE.x, y), Color("172137"), 1.0)
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color("446a9d"), false, 8.0)
	draw_circle(ARENA_SIZE * 0.5, 290.0, Color("1b2a44"))
	draw_arc(ARENA_SIZE * 0.5, 290.0, 0.0, TAU, 96, Color("456eaa"), 3.0)
	for ward in wards:
		draw_circle(ward, 58.0, Color("172542"))
		draw_arc(ward, 58.0, 0.0, TAU, 32, Color("58d9ff"), 3.0)
		draw_circle(ward, 14.0, Color("88efff"))
	draw_circle(objective_position, 78.0, Color("4e398a", 0.26))
	draw_arc(objective_position, 78.0, 0.0, TAU, 40, Color("c084ff"), 3.0)
	draw_circle(objective_position, 19.0, Color("d9a9ff"))
