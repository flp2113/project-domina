class_name LuckWheel
extends Control

# Roleta de sorte dos Eventos "?": cada fatia tem o tamanho da sua chance, a
# roda gira com desaceleração e o ponteiro dourado (fixo no topo) estala a cada
# fatia que passa. O resultado já é conhecido antes de girar (quem chama
# sorteia e passa a chave em spin_to) — a roleta só dramatiza.
#
# segments: [{key, chance, label, kind("good"|"bad"|"danger"|"neutral")}]
# Sinais: tick (ponteiro cruzou uma divisa — gancho pra som) e finished(key).

signal tick()
signal finished(key: String)

const SPIN_SECONDS: float = 3.8
const FULL_TURNS: int = 5
const KIND_COLORS := {
	"good": Color(0.33, 0.72, 0.42),
	"bad": Color(0.92, 0.58, 0.2),
	"danger": Color(0.78, 0.17, 0.22),
	"neutral": Color(0.5, 0.52, 0.62),
}
const GOLD := Color(0.95, 0.75, 0.28)
const DARK := Color(0.08, 0.06, 0.1)

var radius: float = 150.0
var segments: Array = []        # cada um ganha a0/a1 (radianos, no sentido horário a partir do topo)
var wheel_angle: float = 0.0    # rotação horária da roda
var is_spinning: bool = false
var result_key: String = ""
var caption: String = ""
var caption_color: Color = Color.WHITE

var _pointer_kick: float = 0.0
var _last_idx: int = -1
var _highlight_idx: int = -1
var _highlight: float = 0.0
var _tween: Tween = null
var _particles: Array = []
var _clock: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(radius * 2.0 + 60.0, radius * 2.0 + 130.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(p_segments: Array) -> void:
	segments = []
	var total := 0.0
	for s in p_segments:
		total += float(s["chance"])
	var acc := 0.0
	for s in p_segments:
		var seg: Dictionary = s.duplicate()
		seg["a0"] = acc / total * TAU
		acc += float(s["chance"])
		seg["a1"] = acc / total * TAU
		segments.append(seg)
	wheel_angle = 0.0
	result_key = ""
	caption = ""
	_highlight_idx = -1
	_highlight = 0.0
	_last_idx = -1
	_particles.clear()

func _segment_index_at(local_angle: float) -> int:
	var q = fposmod(local_angle, TAU)
	for i in range(segments.size()):
		if q >= segments[i]["a0"] and q < segments[i]["a1"]:
			return i
	return segments.size() - 1

# Gira e termina na fatia `key` (ponto sorteado dentro dela, longe das bordas).
func spin_to(key: String) -> void:
	var idx := -1
	for i in range(segments.size()):
		if segments[i]["key"] == key:
			idx = i
	if idx < 0:
		finished.emit(key)
		return
	result_key = key
	is_spinning = true
	var seg: Dictionary = segments[idx]
	var p: float = lerpf(seg["a0"], seg["a1"], randf_range(0.2, 0.8))
	# O ponto p (ângulo local) tem que parar no topo: p + rotação ≡ 0 (mod TAU).
	var target: float = TAU * FULL_TURNS - p
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "wheel_angle", target, SPIN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_on_stopped.bind(idx))

# Clique durante o giro: acelera até o fim (o resultado não muda).
func skip() -> void:
	if is_spinning and _tween != null and _tween.is_valid():
		_tween.set_speed_scale(12.0)

func _on_stopped(idx: int) -> void:
	is_spinning = false
	_highlight_idx = idx
	var seg: Dictionary = segments[idx]
	caption = seg["label"]
	caption_color = KIND_COLORS.get(seg.get("kind", "neutral"), Color.WHITE).lightened(0.25)
	_burst(seg.get("kind", "neutral"))
	var t = create_tween()
	t.tween_property(self, "_highlight", 1.0, 0.12)
	t.tween_property(self, "_highlight", 0.25, 0.18)
	t.tween_property(self, "_highlight", 1.0, 0.12)
	t.tween_property(self, "_highlight", 0.25, 0.18)
	t.tween_property(self, "_highlight", 0.8, 0.5)
	t.tween_interval(0.35)
	t.tween_callback(func(): finished.emit(result_key))

func _burst(kind: String) -> void:
	var pal: Array
	match kind:
		"good": pal = [GOLD, Color(0.5, 0.9, 0.55), Color(1, 0.95, 0.75)]
		"bad": pal = [Color(0.95, 0.6, 0.2), Color(0.6, 0.4, 0.25)]
		"danger": pal = [Color(0.9, 0.2, 0.25), Color(0.35, 0.05, 0.1), Color(1.0, 0.5, 0.3)]
		_: pal = [Color.WHITE]
	var origin = Vector2(size.x / 2.0, size.y / 2.0 - 20.0)
	for i in range(54):
		var ang = randf_range(-PI * 0.95, -PI * 0.05)
		var spd = randf_range(180.0, 520.0)
		_particles.append({
			"pos": origin + Vector2(randf_range(-20, 20), randf_range(-10, 10)),
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"col": pal[randi() % pal.size()],
			"life": randf_range(0.8, 1.5),
			"max": 1.5,
			"sz": randf_range(4.0, 9.0),
		})

func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	if is_spinning:
		var idx = _segment_index_at(-wheel_angle)
		if idx != _last_idx:
			if _last_idx != -1:
				_pointer_kick = 1.0
				tick.emit()
			_last_idx = idx
	_pointer_kick = maxf(0.0, _pointer_kick - delta * 6.0)
	for p in _particles:
		p["vel"].y += 900.0 * delta
		p["pos"] += p["vel"] * delta
		p["life"] -= delta
	_particles = _particles.filter(func(p): return p["life"] > 0.0)
	queue_redraw()

static func _dir(phi: float) -> Vector2:
	# Ângulo horário medido a partir do topo.
	return Vector2(sin(phi), -cos(phi))

func _draw() -> void:
	var font = ThemeDB.fallback_font
	var c = Vector2(size.x / 2.0, size.y / 2.0 - 20.0)

	# Base: disco escuro com aro dourado + luzes que piscam (correm enquanto gira).
	draw_circle(c + Vector2(0, 8), radius + 22.0, Color(0, 0, 0, 0.45))
	draw_circle(c, radius + 20.0, Color(0.14, 0.1, 0.18))
	draw_arc(c, radius + 20.0, 0, TAU, 64, GOLD, 4.0)
	var bulbs = 24
	for k in range(bulbs):
		var a = TAU * k / bulbs
		var on: bool
		if is_spinning:
			on = int(_clock * 14.0 + k) % 3 == 0
		else:
			on = (k + int(_clock * 3.0)) % 2 == 0
		draw_circle(c + _dir(a) * (radius + 11.0), 4.0, Color(1.0, 0.92, 0.55) if on else Color(0.45, 0.33, 0.15))

	# Fatias.
	for i in range(segments.size()):
		var seg: Dictionary = segments[i]
		var col: Color = KIND_COLORS.get(seg.get("kind", "neutral"), Color.GRAY)
		if i == _highlight_idx:
			col = col.lerp(Color.WHITE, 0.55 * _highlight)
		var a0: float = seg["a0"] + wheel_angle
		var a1: float = seg["a1"] + wheel_angle
		var steps = maxi(3, int(ceil((a1 - a0) / TAU * 72.0)))
		var pts = PackedVector2Array([c])
		for s in range(steps + 1):
			pts.append(c + _dir(lerpf(a0, a1, float(s) / steps)) * radius)
		draw_colored_polygon(pts, col)
		draw_line(c, c + _dir(a0) * radius, DARK, 3.0)

	# Rótulos tangentes à roda (na fatia vencedora, parada no topo, ficam retos).
	for i in range(segments.size()):
		var seg: Dictionary = segments[i]
		var mid: float = (seg["a0"] + seg["a1"]) / 2.0 + wheel_angle
		var at = c + _dir(mid) * (radius * 0.66)
		draw_set_transform(at, mid, Vector2.ONE)
		var w = radius * 0.8
		draw_string(font, Vector2(-w / 2.0 + 2, 9), seg["label"], HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(-w / 2.0, 7), seg["label"], HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(1, 1, 1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_arc(c, radius, 0, TAU, 64, DARK, 4.0)
	# Cubo central.
	draw_circle(c, 24.0, DARK)
	draw_circle(c, 19.0, GOLD)
	draw_circle(c, 8.0, Color(0.55, 0.38, 0.12))

	# Ponteiro fixo no topo (estala ao cruzar divisas).
	var pivot = c + Vector2(0, -radius - 26.0)
	draw_set_transform(pivot, sin(_clock * 60.0) * 0.32 * _pointer_kick, Vector2.ONE)
	var tri = PackedVector2Array([Vector2(-15, -4), Vector2(15, -4), Vector2(0, 46)])
	draw_colored_polygon(tri, GOLD)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), DARK, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Resultado.
	if caption != "":
		var cp = Vector2(size.x / 2.0, c.y + radius + 62.0)
		draw_string(font, cp + Vector2(-size.x / 2.0 + 2, 3), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 36, Color(0, 0, 0, 0.8))
		draw_string(font, cp + Vector2(-size.x / 2.0, 0), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 36, caption_color)

	# Confete / faíscas.
	for p in _particles:
		var a = clampf(p["life"] / 0.5, 0.0, 1.0)
		var col: Color = p["col"]
		draw_rect(Rect2(p["pos"] - Vector2.ONE * p["sz"] / 2.0, Vector2.ONE * p["sz"]), Color(col.r, col.g, col.b, a))
