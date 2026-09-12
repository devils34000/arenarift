extends Node3D

@export var rotation_speed := 0.35
@export var pulse_speed := 2.0
@export var pulse_amount := 0.08

@onready var circle := $Circle
@onready var glow := $Glow
var time := 0.0

func _process(delta: float) -> void:
    time += delta
    circle.rotation.y += rotation_speed * delta
    glow.rotation.y -= rotation_speed * 0.65 * delta
    var pulse := 1.0 + sin(time * pulse_speed) * pulse_amount
    circle.scale = Vector3.ONE * pulse
    glow.scale = Vector3.ONE * (1.02 + sin(time * pulse_speed + 0.8) * pulse_amount)
