class_name ContentRegistry
extends RefCounted

const ROOM_PATHS := [
	"res://data/rooms/rest.tres",
	"res://data/rooms/commons.tres",
	"res://data/rooms/grow.tres",
	"res://data/rooms/workshop.tres",
	"res://data/rooms/power.tres",
	"res://data/rooms/airlock.tres",
]
const ENEMY_PATHS := [
	"res://data/enemies/melee.tres",
	"res://data/enemies/ranged.tres",
	"res://data/enemies/elite.tres",
]
const STAGE_PATHS := [
	"res://data/stages/arcade.tres",
	"res://data/stages/transit.tres",
	"res://data/stages/foundry.tres",
]

static var _rooms: Array = []
static var _enemies: Array = []
static var _stages: Array = []


static func rooms() -> Array:
	if _rooms.is_empty():
		_rooms = _load_all(ROOM_PATHS)
	return _rooms


static func buildable_rooms() -> Array:
	return rooms().filter(func(definition: RoomDefinition) -> bool: return definition.id != "airlock")


static func enemies() -> Array:
	if _enemies.is_empty():
		_enemies = _load_all(ENEMY_PATHS)
	return _enemies


static func stages() -> Array:
	if _stages.is_empty():
		_stages = _load_all(STAGE_PATHS)
	return _stages


static func room(id: String) -> RoomDefinition:
	for definition: RoomDefinition in rooms():
		if definition.id == id:
			return definition
	return null


static func enemy(id: String) -> EnemyDefinition:
	for definition: EnemyDefinition in enemies():
		if definition.id == id:
			return definition
	return null


static func stage(id: String) -> StageDefinition:
	for definition: StageDefinition in stages():
		if definition.id == id:
			return definition
	return stages()[0]


static func _load_all(paths: Array) -> Array:
	var loaded: Array = []
	for path: String in paths:
		var resource := load(path)
		if resource:
			loaded.append(resource)
	return loaded

