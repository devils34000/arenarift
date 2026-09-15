@tool
extends Node3D
## Applique les matériaux texturés KatsBits partagés (mur/sol/pilier) à
## toutes les pièces FBX instanciées sous ce nœud, sans toucher à la
## géométrie ni aux connecteurs déjà pré-cuits. Nécessaire car les meshes
## importés du pack KatsBits-fantasy-base n'ont pas de texture assignée
## par défaut (juste une couleur de secours arbitraire par matériau FBX).

const WALL_MATERIAL := preload("res://scenes/dungeon/materials/DungeonWallMaterial.tres")
const FLOOR_MATERIAL := preload("res://scenes/dungeon/materials/DungeonFloorMaterial.tres")
const PILLAR_MATERIAL := preload("res://scenes/dungeon/materials/DungeonPillarMaterial.tres")

func _ready() -> void:
	for child in get_children():
		var mat: Material = WALL_MATERIAL
		if "Floor" in String(child.name):
			mat = FLOOR_MATERIAL
		elif "Pillar" in String(child.name):
			mat = PILLAR_MATERIAL
		_apply_material(child, mat)

func _apply_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_material(child, mat)
