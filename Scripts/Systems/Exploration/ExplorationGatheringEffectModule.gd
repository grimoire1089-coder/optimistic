extends Node2D
class_name ExplorationGatheringEffectModule

const INVENTORY_BUTTON_GROUP: StringName = &"inventory_button"

@export var icon_size: float = 34.0
@export var grow_duration: float = 0.28
@export var hold_duration: float = 0.18
@export var fly_duration: float = 0.56
@export var pickup_rise_distance: float = 34.0
@export var particle_count: int = 12
@export var particle_spread: float = 42.0
@export var fallback_target_position: Vector2 = Vector2(1516.0, 212.0)
@export var glow_color: Color = Color(0.20, 1.0, 0.95, 0.88)
@export var particle_color: Color = Color(0.42, 1.0, 0.90, 0.92)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_as_relative = false
	z_index = 120
	_rng.randomize()


func play_gathering_item_effect(icon_path: String, item_display_name: String, amount: int, source_global_position: Vector2) -> void:
	var effect_root := Node2D.new()
	effect_root.name = "GatheringItemPickupEffect"
	effect_root.global_position = source_global_position
	effect_root.z_as_relative = false
	effect_root.z_index = 120
	add_child(effect_root)

	var glow := _make_glow_square()
	effect_root.add_child(glow)

	var icon_sprite := Sprite2D.new()
	icon_sprite.name = "ItemIcon"
	icon_sprite.centered = true
	icon_sprite.texture = _load_texture(icon_path)
	icon_sprite.z_index = 3
	icon_sprite.scale = Vector2.ZERO
	effect_root.add_child(icon_sprite)
	_fit_sprite_to_size(icon_sprite, icon_size)
	icon_sprite.scale = Vector2.ZERO

	for index in range(maxi(particle_count, 0)):
		var particle := _make_particle_square(index)
		effect_root.add_child(particle)

	var target_position := _get_inventory_button_center()
	var grow_position := source_global_position + Vector2(0.0, -maxf(pickup_rise_distance, 0.0))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect_root, "global_position", grow_position, maxf(grow_duration, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon_sprite, "scale", _get_icon_target_scale(icon_sprite), maxf(grow_duration, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "modulate:a", 0.96, maxf(grow_duration, 0.01))
	for child in effect_root.get_children():
		if child == icon_sprite or child == glow:
			continue
		var particle_node := child as Control
		if particle_node == null:
			continue
		var random_offset := Vector2(
			_rng.randf_range(-particle_spread, particle_spread),
			_rng.randf_range(-particle_spread, particle_spread)
		)
		tween.tween_property(particle_node, "position", random_offset, maxf(grow_duration, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle_node, "rotation", _rng.randf_range(-1.8, 1.8), maxf(grow_duration, 0.01))

	var fly_tween := create_tween()
	fly_tween.tween_interval(maxf(grow_duration + hold_duration, 0.01))
	fly_tween.tween_property(effect_root, "global_position", target_position, maxf(fly_duration, 0.01)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fly_tween.parallel().tween_property(effect_root, "scale", Vector2(0.36, 0.36), maxf(fly_duration, 0.01)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly_tween.parallel().tween_property(effect_root, "modulate:a", 0.0, maxf(fly_duration, 0.01)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly_tween.tween_callback(Callable(effect_root, "queue_free"))


func _make_glow_square() -> ColorRect:
	var glow := ColorRect.new()
	glow.name = "GlowSquare"
	glow.color = glow_color
	glow.custom_minimum_size = Vector2(52.0, 52.0)
	glow.size = glow.custom_minimum_size
	glow.position = -glow.size * 0.5
	glow.modulate.a = 0.0
	glow.rotation = 0.78
	glow.z_index = 1
	return glow


func _make_particle_square(index: int) -> ColorRect:
	var particle := ColorRect.new()
	particle.name = "GlowParticle_%02d" % index
	var size := _rng.randf_range(5.0, 10.0)
	particle.color = particle_color
	particle.custom_minimum_size = Vector2(size, size)
	particle.size = particle.custom_minimum_size
	particle.position = -particle.size * 0.5
	particle.pivot_offset = particle.size * 0.5
	particle.rotation = _rng.randf_range(-1.0, 1.0)
	particle.modulate.a = _rng.randf_range(0.55, 0.95)
	particle.z_index = 2
	return particle


func _fit_sprite_to_size(sprite: Sprite2D, target_size: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	var texture_size := sprite.texture.get_size()
	var max_side := maxf(texture_size.x, texture_size.y)
	if max_side <= 0.0:
		return
	var scale_value := maxf(target_size, 1.0) / max_side
	sprite.scale = Vector2(scale_value, scale_value)


func _get_icon_target_scale(sprite: Sprite2D) -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2.ONE
	var texture_size := sprite.texture.get_size()
	var max_side := maxf(texture_size.x, texture_size.y)
	if max_side <= 0.0:
		return Vector2.ONE
	var scale_value := maxf(icon_size, 1.0) / max_side
	return Vector2(scale_value, scale_value)


func _get_inventory_button_center() -> Vector2:
	var button := get_tree().get_first_node_in_group(INVENTORY_BUTTON_GROUP) as Control
	if button != null and is_instance_valid(button):
		return button.get_global_rect().get_center()
	var scene_root := get_tree().current_scene
	if scene_root != null:
		var canvas_layer := scene_root.get_node_or_null("CanvasLayer")
		if canvas_layer != null:
			var inventory_button := canvas_layer.get_node_or_null("InventoryButton") as Control
			if inventory_button != null:
				return inventory_button.get_global_rect().get_center()
	return fallback_target_position


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
