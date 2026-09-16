extends Node3D

const CELL := 2.5
const WALL_H := 3.2
const WALL_T := 0.35
const FLOOR_T := 0.18
const MAP := [
"###############################",
"#........#.........#..........#",
"#.######.#.#######.#.########.#",
"#.#....#.#.#.....#.#.#......#.#",
"#.#.##.#.#.#.###.#.#.#.####.#.#",
"#...##...#...#...#...#....#...#",
"###.######.###.#######.#######",
"#...#......#...#.....#.......#",
"#.###.######.#.#.###.#######.#",
"#.....#....#.#.#...#.#.......#",
"#.#####.##.#.#.###.#.#.#####.#",
"#.#.....#..#...#...#...#...#.#",
"#.#.#####.######.#######.#.#.#",
"#...#.....#....#.......#.#...#",
"#####.###.#.##.#######.#.#####",
"#.....#...#..#.....#...#.....#",
"#.#####.#####.###.#.#####.##.#",
"#.......#.....#...#.....#....#",
"#.#######.#####.#######.###.#",
"#.........#.........#.......#",
"#.#########.#######.#.#####.#",
"#...........#.....#.........#",
"###############################"
]

func _ready() -> void:
    _build()
    _setup_camera()

func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, material: Material) -> void:
    var body := StaticBody3D.new()
    body.name = name
    body.position = pos
    parent.add_child(body)
    var mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = size
    mesh.mesh = cube
    mesh.material_override = material
    body.add_child(mesh)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)

func _mat(color: Color, rough := 0.9) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    return m

func _build() -> void:
    var root := Node3D.new()
    root.name = "GeneratedDungeon"
    add_child(root)
    var floor_mat := _mat(Color("#34343a"))
    var wall_mat := _mat(Color("#55515a"))
    var accent_mat := _mat(Color("#263b50"))
    var origin := Vector3(-float(MAP[0].length()) * CELL * 0.5, 0, -float(MAP.size()) * CELL * 0.5)
    for z in MAP.size():
        for x in MAP[z].length():
            if MAP[z][x] == '.':
                var p := origin + Vector3(x * CELL + CELL * 0.5, -FLOOR_T * 0.5, z * CELL + CELL * 0.5)
                _box(root, "Floor_%02d_%02d" % [x,z], p, Vector3(CELL, FLOOR_T, CELL), floor_mat)
                if (x + z) % 7 == 0:
                    _box(root, "Rune_%02d_%02d" % [x,z], p + Vector3(0,0.1,0), Vector3(CELL*0.25,0.04,CELL*0.25), accent_mat)
            else:
                var p := origin + Vector3(x * CELL + CELL * 0.5, WALL_H * 0.5, z * CELL + CELL * 0.5)
                _box(root, "Wall_%02d_%02d" % [x,z], p, Vector3(CELL + WALL_T, WALL_H, CELL + WALL_T), wall_mat)
    _room(root, origin, 2, 2, 5, 4, "Entrance")
    _room(root, origin, 12, 9, 7, 5, "CentralHall")
    _room(root, origin, 24, 1, 5, 5, "BossRoom")

func _room(root: Node3D, origin: Vector3, gx: int, gz: int, w: int, h: int, room_name: String) -> void:
    var floor_mat := _mat(Color("#45414b"))
    for z in range(gz, gz+h):
        for x in range(gx, gx+w):
            var p := origin + Vector3(x * CELL + CELL*0.5, -FLOOR_T*0.5, z * CELL + CELL*0.5)
            _box(root, room_name+"_Floor", p, Vector3(CELL,FLOOR_T,CELL), floor_mat)

func _setup_camera() -> void:
    var cam := Camera3D.new()
    cam.position = Vector3(0, 58, 8)
    cam.rotation_degrees = Vector3(-90, 0, 0)
    cam.current = true
    cam.fov = 55
    add_child(cam)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55,-25,0)
    light.light_energy = 1.4
    add_child(light)
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("#09090d")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("#8d87a6")
    e.ambient_light_energy = 0.65
    env.environment = e
    add_child(env)
