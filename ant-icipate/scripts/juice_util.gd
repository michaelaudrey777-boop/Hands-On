extends RefCounted

static var _soft_circle: Texture2D = null

## White soft round blob. Used as the particle texture, so no art file is needed.
static func soft_circle() -> Texture2D:
	if _soft_circle != null:
		return _soft_circle

	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32

	_soft_circle = tex
	return tex

static func fade_ramp(start_alpha: float) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, start_alpha))
	g.set_color(1, Color(1, 1, 1, 0.0))
	return g

## Particles fade in and out, no popping.
static func fade_in_out_ramp(max_alpha: float, fade_in: float = 0.15) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(fade_in, Color(1, 1, 1, max_alpha))
	return g
	
## Finds the first Sprite2D or AnimatedSprite2D child, whatever it is named.
static func find_sprite(parent: Node) -> Node2D:
	for child in parent.get_children():
		if (child is Sprite2D or child is AnimatedSprite2D) \
				and not child.name.to_lower().contains("shadow"):
			return child
	return null
