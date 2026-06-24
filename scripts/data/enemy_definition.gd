class_name EnemyDefinition
extends Resource

enum Archetype { MELEE, RANGED, ELITE }

@export var id := ""
@export var display_name := ""
@export var archetype := Archetype.MELEE
@export var max_health := 50.0
@export var move_speed := 35.0
@export var damage := 10.0
@export var attack_range := 22.0
@export var attack_cooldown := 1.2
@export var knockback_force := 28.0
@export var loot_value := 10
@export var body_color := Color.WHITE
@export var glow_color := Color.WHITE

