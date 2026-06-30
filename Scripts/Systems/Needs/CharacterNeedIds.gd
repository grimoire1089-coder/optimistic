extends RefCounted
class_name CharacterNeedIds

const HUNGER := &"hunger"
const WATER := &"water"
const ENERGY := &"energy"
const HYGIENE := &"hygiene"
const FUN := &"fun"
const SOCIAL := &"social"

const DEFAULT_DEFINITION_PATHS := [
	"res://Data/Needs/Definitions/energy.tres",
	"res://Data/Needs/Definitions/hunger.tres",
	"res://Data/Needs/Definitions/water.tres",
	"res://Data/Needs/Definitions/hygiene.tres",
	"res://Data/Needs/Definitions/fun.tres",
	"res://Data/Needs/Definitions/social.tres",
]

static func get_default_definition_paths() -> Array[String]:
	var result: Array[String] = []
	for path in DEFAULT_DEFINITION_PATHS:
		result.append(path)
	return result
