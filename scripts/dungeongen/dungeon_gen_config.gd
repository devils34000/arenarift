extends Resource
class_name DungeonGenConfig
## Réglages d'une génération de donjon : quels blocs sont disponibles
## dans quel rôle, et les paramètres de forme/taille du résultat.

@export_category("Pools de blocs")
@export var entrance_pool: Array[DungeonPieceData] = []
@export var corridor_pool: Array[DungeonPieceData] = []
@export var room_pool: Array[DungeonPieceData] = []
@export var dead_end_pool: Array[DungeonPieceData] = []
@export var boss_pool: Array[DungeonPieceData] = []

@export_category("Forme du chemin principal")
## Nombre de blocs sur le chemin principal, entrée et salle boss incluses.
@export var main_path_length: int = 8

@export_category("Embranchements")
## Nombre de branches latérales tentées (best-effort : une branche qui ne
## trouve pas de place est simplement abandonnée, la génération continue).
@export var branch_count: int = 3
@export var branch_depth_min: int = 1
@export var branch_depth_max: int = 3

@export_category("Résolution des collisions")
## Marge de sécurité (mètres) retirée de chaque côté de la boîte englobante
## d'un bloc avant de tester un chevauchement avec les blocs déjà posés.
## Augmente cette valeur si des blocs se chevauchent visuellement malgré
## des portes bien alignées ; baisse-la si des blocs valides sont refusés
## à tort.
@export var overlap_margin: float = 0.05
## Nombre de blocs candidats essayés avant d'abandonner UNE étape (pas
## toute la génération) et de revenir en arrière.
@export var max_attempts_per_step: int = 25
## Nombre de tentatives complètes (nouvelle seed à chaque fois) avant
## d'abandonner totalement la génération.
@export var max_generation_attempts: int = 20

@export_category("Aléatoire")
## 0 = aléatoire à chaque génération. Toute autre valeur = résultat
## reproductible (pratique pour déboguer un agencement précis).
@export var random_seed: int = 0
