extends Node2D
class_name ExplorationGatheringEffectModule

const INVENTORY_BUTTON_GROUP: StringName = &"inventory_button"

@export var icon_size: float = 48.0
@export var foot_anchor_extra_offset: Vector2 = Vector2(-8.0, 54.0)
@export var sprout_duration: float = 1.80
@export var bounce_expand_duration: float = 0.18
@export var bounce_settle_duration: float = 0.30
@export var particle_gather_duration: float = 0.90
@export var hold_duration: float = 0.85
@export var fly_duration: float = 2.55
@export var sprout_rise_distance: float = 18.0
@export var arc_height: float = 300.0
@export var arc_side_offset: float = 220.0
@export var particle_count: int = 28
@export var particle_orbit_radius: float = 42.0
@export var particle_orbit_jitter: float = 18.0
@export var particle_peel_distance: float = 110.0
@export var particle_fall_distance: float = 72.0
@export var particle_peel_spread: float = 48.0
@export var particle_peel_delay_ratio: float = 0.42
@export var fallback_target_position: Vector2 = Vector2(1516.0, 212.0)
@export var glow_color: Color = Color(0.20, 1.0, 0.95, 0.88)
@export var overbright_glow_color: Color = Color(0.35, 2.2, 2.6, 0.55)
@export var particle_color: Color = Color(0.42, 1.0, 0.90, 0.92)
@export var arc_trail_count: int = 8
@export var beam_orb_turns: float = 3.25
@export var item_fly_rotation_turns: float = 1.25

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_as_relative = false
	z_index = 120
	_rng.randomize()


func play_gathering_item_effect(icon_path: String, item_display_name: String, amount: int, source_global_position: Vector2) -> void:
	var start_position := source_global_position + foot_anchor_extra_offset
	var effect_root := Node2D.new()
	effect_root.name = "GatheringItemPickupEffect"
	effect_root.global_position = start_position
	effect_root.z_as_relative = false
	effect_root.z_index = 120
	add_child(effect_root)

	var beam_ball_root := Node2D.new()
	beam_ball_root.name = "BeamOrb"
	beam_ball_root.position = Vector2(0.0, -icon_size * 0.5)
	beam_ball_root.z_index = 3
	effect_root.add_child(beam_ball_root)

	var outer_glow := _make_glow_square("OuterGlowSquare", 108.0, overbright_glow_color, 0.16, 0.0, 0.18)
	effect_root.add_child(outer_glow)

	var core_glow := _make_glow_square("CoreGlowSquare", 70.0, glow_color, 0.24, 0.0, 0.34)
	effect_root.add_child(core_glow)

	var beam_core := _make_beam_orb_square("BeamOrbCore", 44.0, overbright_glow_color, 0.0, 0.0)
	beam_ball_root.add_child(beam_core)

	var beam_ring := _make_beam_orb_square("BeamOrbRing", 70.0, glow_color, 0.0, 0.16)
	beam_ball_root.add_child(beam_ring)

	var icon_texture := _load_texture(icon_path)
	var icon_glow_sprite := Sprite2D.new()
	icon_glow_sprite.name = "ItemIconGlow"
	icon_glow_sprite.centered = true
	icon_glow_sprite.texture = icon_texture
	icon_glow_sprite.z_index = 2
	icon_glow_sprite.position = beam_ball_root.position
	icon_glow_sprite.modulate = overbright_glow_color
	icon_glow_sprite.material = _make_additive_material()
	effect_root.add_child(icon_glow_sprite)
	var icon_target_scale := _get_icon_target_scale(icon_glow_sprite)
	icon_glow_sprite.scale = Vector2(icon_target_scale.x * 0.10, icon_target_scale.y * 0.03)
	icon_glow_sprite.modulate.a = 0.0

	var icon_sprite := Sprite2D.new()
	icon_sprite.name = "ItemIcon"
	icon_sprite.centered = true
	icon_sprite.texture = icon_texture
	icon_sprite.z_index = 5
	icon_sprite.position = beam_ball_root.position
	effect_root.add_child(icon_sprite)
	icon_sprite.scale = Vector2(icon_target_scale.x * 0.08, icon_target_scale.y * 0.02)
	icon_sprite.modulate.a = 0.0

	for trail_index in range(maxi(arc_trail_count, 0)):
		var trail := _make_arc_trail_square(trail_index)
		beam_ball_root.add_child(trail)

	for index in range(maxi(particle_count, 0)):
		var particle := _make_particle_square(index)
		beam_ball_root.add_child(particle)

	var target_position := _get_inventory_button_center()
	var sprout_position := start_position + Vector2(0.0, -maxf(sprout_rise_distance, 0.0))

	var sprout_tween := create_tween()
	sprout_tween.set_parallel(true)
	sprout_tween.tween_property(effect_root, "global_position", sprout_position, maxf(sprout_duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sprout_tween.tween_property(icon_sprite, "scale", icon_target_scale, maxf(sprout_duration, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sprout_tween.tween_property(icon_sprite, "modulate:a", 1.0, maxf(sprout_duration * 0.52, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sprout_tween.tween_property(icon_glow_sprite, "scale", icon_target_scale * 1.45, maxf(sprout_duration, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sprout_tween.tween_property(icon_glow_sprite, "modulate:a", 0.62, maxf(sprout_duration * 0.74, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sprout_tween.tween_property(core_glow, "modulate:a", 0.76, maxf(sprout_duration * 0.74, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sprout_tween.tween_property(core_glow, "scale", Vector2(1.24, 1.24), maxf(sprout_duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sprout_tween.tween_property(outer_glow, "modulate:a", 0.48, maxf(sprout_duration * 0.88, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sprout_tween.tween_property(outer_glow, "scale", Vector2(1.42, 1.42), maxf(sprout_duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sprout_tween.tween_property(beam_core, "modulate:a", 0.72, maxf(sprout_duration * 0.70, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sprout_tween.tween_property(beam_core, "scale", Vector2(1.0, 1.0), maxf(sprout_duration, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sprout_tween.tween_property(beam_ring, "modulate:a", 0.42, maxf(sprout_duration * 0.85, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sprout_tween.tween_property(beam_ring, "scale", Vector2(1.05, 1.05), maxf(sprout_duration, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var particle_tween := create_tween()
	particle_tween.tween_interval(maxf(sprout_duration * 0.62, 0.01))
	for child in beam_ball_root.get_children():
		var particle_node := child as Control
		if particle_node == null:
			continue
		if not particle_node.has_meta(&"target_position"):
			continue
		var target_particle_position := particle_node.get_meta(&"target_position") as Vector2
		var alpha := float(particle_node.get_meta(&"target_alpha", 0.82))
		particle_tween.parallel().tween_property(particle_node, "position", target_particle_position, maxf(particle_gather_duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		particle_tween.parallel().tween_property(particle_node, "rotation", _rng.randf_range(-2.6, 2.6), maxf(particle_gather_duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		particle_tween.parallel().tween_property(particle_node, "modulate:a", alpha, maxf(particle_gather_duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var orbit_tween := create_tween()
	orbit_tween.tween_interval(maxf(sprout_duration * 0.55, 0.01))
	orbit_tween.tween_property(beam_ball_root, "rotation", TAU * maxf(beam_orb_turns, 0.0), maxf(sprout_duration + hold_duration + fly_duration, 0.01)).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	var bounce_tween := create_tween()
	bounce_tween.tween_interval(maxf(sprout_duration, 0.01))
	bounce_tween.tween_property(icon_sprite, "scale", icon_target_scale * 1.28, maxf(bounce_expand_duration, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce_tween.parallel().tween_property(icon_glow_sprite, "scale", icon_target_scale * 1.86, maxf(bounce_expand_duration, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce_tween.parallel().tween_property(core_glow, "scale", Vector2(1.55, 1.55), maxf(bounce_expand_duration, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(icon_sprite, "scale", icon_target_scale, maxf(bounce_settle_duration, 0.01)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	bounce_tween.parallel().tween_property(icon_glow_sprite, "scale", icon_target_scale * 1.45, maxf(bounce_settle_duration, 0.01)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	bounce_tween.parallel().tween_property(core_glow, "scale", Vector2(1.24, 1.24), maxf(bounce_settle_duration, 0.01)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var arc_start := sprout_position
	var arc_control := _get_arc_control_point(arc_start, target_position)
	var fly_start_delay := maxf(sprout_duration + hold_duration + bounce_expand_duration + bounce_settle_duration, 0.01)
	var fly_tween := create_tween()
	fly_tween.tween_interval(fly_start_delay)
	fly_tween.tween_method(
		Callable(self, "_apply_arc_position").bind(effect_root, arc_start, arc_control, target_position),
		0.0,
		1.0,
		maxf(fly_duration, 0.01)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly_tween.parallel().tween_property(effect_root, "scale", Vector2(0.28, 0.28), maxf(fly_duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly_tween.parallel().tween_property(icon_sprite, "rotation", TAU * item_fly_rotation_turns, maxf(fly_duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly_tween.parallel().tween_property(icon_glow_sprite, "rotation", TAU * item_fly_rotation_turns, maxf(fly_duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly_tween.parallel().tween_property(icon_glow_sprite, "scale", icon_target_scale * 2.8, maxf(fly_duration * 0.65, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fly_tween.parallel().tween_property(outer_glow, "scale", Vector2(2.05, 2.05), maxf(fly_duration * 0.65, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fly_tween.tween_callback(Callable(effect_root, "queue_free"))

	var root_fade_tween := create_tween()
	root_fade_tween.tween_interval(fly_start_delay + fly_duration * 0.58)
	root_fade_tween.tween_property(effect_root, "modulate:a", 0.0, maxf(fly_duration * 0.42, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_play_particle_peel_effects(beam_ball_root, arc_start, target_position, fly_start_delay)


func _play_particle_peel_effects(beam_ball_root: Node2D, arc_start: Vector2, target_position: Vector2, fly_start_delay: float) -> void:
	if beam_ball_root == null:
		return
	var travel_direction := target_position - arc_start
	if travel_direction.length_squared() <= 0.001:
		travel_direction = Vector2.RIGHT
	travel_direction = travel_direction.normalized()
	var peel_direction := -travel_direction
	for child in beam_ball_root.get_children():
		var particle_node := child as Control
		if particle_node == null:
			continue
		if not String(particle_node.name).begins_with("BeamParticle_"):
			continue
		var base_position := particle_node.position
		if particle_node.has_meta(&"target_position"):
			base_position = particle_node.get_meta(&"target_position") as Vector2
		var peel_offset := peel_direction * _rng.randf_range(particle_peel_distance * 0.45, particle_peel_distance)
		peel_offset += Vector2(
			_rng.randf_range(-particle_peel_spread, particle_peel_spread),
			_rng.randf_range(particle_fall_distance * 0.35, particle_fall_distance)
		)
		var delay := fly_start_delay + _rng.randf_range(0.0, maxf(fly_duration * particle_peel_delay_ratio, 0.01))
		var duration := _rng.randf_range(maxf(fly_duration * 0.42, 0.01), maxf(fly_duration * 0.82, 0.02))
		var peel_tween := create_tween()
		peel_tween.tween_interval(delay)
		peel_tween.tween_property(particle_node, "position", base_position + peel_offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		peel_tween.parallel().tween_property(particle_node, "rotation", particle_node.rotation + _rng.randf_range(-3.2, 3.2), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		peel_tween.parallel().tween_property(particle_node, "scale", Vector2(0.28, 0.28), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		peel_tween.parallel().tween_property(particle_node, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _make_glow_square(node_name: String, size: float, color: Color, start_scale: float, start_alpha: float, rotation_offset: float) -> ColorRect:
	var glow := ColorRect.new()
	glow.name = node_name
	glow.color = color
	glow.material = _make_additive_material()
	glow.custom_minimum_size = Vector2(size, size)
	glow.size = glow.custom_minimum_size
	glow.position = -glow.size * 0.5 + Vector2(0.0, -icon_size * 0.5)
	glow.pivot_offset = glow.size * 0.5
	glow.modulate.a = start_alpha
	glow.scale = Vector2(start_scale, start_scale)
	glow.rotation = 0.78 + rotation_offset
	glow.z_index = 1
	return glow


func _make_beam_orb_square(node_name: String, size: float, color: Color, start_alpha: float, rotation_offset: float) -> ColorRect:
	var square := ColorRect.new()
	square.name = node_name
	square.color = color
	square.material = _make_additive_material()
	square.custom_minimum_size = Vector2(size, size)
	square.size = square.custom_minimum_size
	square.position = -square.size * 0.5
	square.pivot_offset = square.size * 0.5
	square.modulate.a = start_alpha
	square.scale = Vector2(0.12, 0.12)
	square.rotation = 0.78 + rotation_offset
	square.z_index = 1
	return square


func _make_particle_square(index: int) -> ColorRect:
	var particle := ColorRect.new()
	particle.name = "BeamParticle_%02d" % index
	var size := _rng.randf_range(4.0, 9.0)
	particle.color = particle_color
	particle.material = _make_additive_material()
	particle.custom_minimum_size = Vector2(size, size)
	particle.size = particle.custom_minimum_size
	particle.position = Vector2(-size * 0.5, -size * 0.5)
	particle.pivot_offset = particle.size * 0.5
	particle.rotation = _rng.randf_range(-1.0, 1.0)
	var angle := _rng.randf_range(0.0, TAU)
	var radius := maxf(particle_orbit_radius + _rng.randf_range(-particle_orbit_jitter, particle_orbit_jitter), 4.0)
	var target_position := Vector2(cos(angle), sin(angle)) * radius - particle.size * 0.5
	particle.set_meta(&"target_position", target_position)
	var alpha := _rng.randf_range(0.55, 0.95)
	particle.set_meta(&"target_alpha", alpha)
	particle.modulate.a = 0.0
	particle.z_index = 4
	return particle


func _make_arc_trail_square(index: int) -> ColorRect:
	var trail := ColorRect.new()
	trail.name = "ArcGlowTrail_%02d" % index
	var size := 11.0 + float(index) * 2.25
	trail.color = Color(overbright_glow_color.r, overbright_glow_color.g, overbright_glow_color.b, 0.32)
	trail.material = _make_additive_material()
	trail.custom_minimum_size = Vector2(size, size)
	trail.size = trail.custom_minimum_size
	trail.position = Vector2(-size * 0.5, -size * 0.5)
	trail.pivot_offset = trail.size * 0.5
	trail.scale = Vector2(0.18, 0.18)
	trail.rotation = _rng.randf_range(-1.0, 1.0)
	trail.modulate.a = 0.0
	trail.set_meta(&"target_position", Vector2(_rng.randf_range(-16.0, 16.0), _rng.randf_range(-16.0, 16.0)) - trail.size * 0.5)
	trail.set_meta(&"target_alpha", 0.16 + float(index) * 0.03)
	trail.z_index = 0
	return trail


func _apply_arc_position(t: float, effect_root: Node2D, start_position: Vector2, control_position: Vector2, end_position: Vector2) -> void:
	if effect_root == null or not is_instance_valid(effect_root):
		return
	var eased_t := clampf(t, 0.0, 1.0)
	var a := start_position.lerp(control_position, eased_t)
	var b := control_position.lerp(end_position, eased_t)
	effect_root.global_position = a.lerp(b, eased_t)


func _get_arc_control_point(start_position: Vector2, end_position: Vector2) -> Vector2:
	var midpoint := (start_position + end_position) * 0.5
	var direction := end_position - start_position
	var side := 1.0
	if direction.x < 0.0:
		side = -1.0
	return midpoint + Vector2(side * maxf(arc_side_offset, 0.0), -maxf(arc_height, 0.0))


func _get_icon_target_scale(sprite: Sprite2D) -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2.ONE
	var texture_size := sprite.texture.get_size()
	var max_side := maxf(texture_size.x, texture_size.y)
	if max_side <= 0.0:
		return Vector2.ONE
	var scale_value := maxf(icon_size, 1.0) / max_side
	return Vector2(scale_value, scale_value)


func _make_additive_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


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
