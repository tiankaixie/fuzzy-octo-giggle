class_name StageDefinition
extends Resource

@export var id := ""
@export var display_name := ""
@export var sector := ""
@export_multiline var description := ""
@export var risk := "LOW"
@export var recommended_level := "LV.01"
@export var accent_color := Color.WHITE
@export var map_position := Vector2.ZERO
@export var room_names: Array[String] = []
@export var room_codes: Array[String] = []
@export var room_waves: Array[String] = []
@export var clear_bonus := 30

