class_name EventView
extends Control

# Nó "?" do mapa: um encontro com 2-3 escolhas e consequências (ouro, cartas,
# Leis). Segue o mesmo padrão visual/estrutural da MESA DE APOSTAS (BetView):
# HUD lateral, fundo de bioma, inventário e tooltips. Alguns desfechos terminam em EMBOSCADA (duelo 6x6). Cada evento sai de
# _build_events() (dados) e é resolvido em _resolve() (efeitos); nenhum evento
# se repete numa mesma run (RunManager.seen_event_ids).

const MAP_SCENE_PATH: String = "res://map_view.tscn"
const PREVIEW_SCALE: float = 0.95

# --- Balanceamento (um evento rende algo na faixa de um duelo comum: ~7-14 ouro) ---
# Cofre: sucesso / agulha (perde ouro) / o resto é EMBOSCADA.
const CHEST_WIN_CHANCE: float = 0.5
const CHEST_NEEDLE_CHANCE: float = 0.25
const CHEST_AMBUSH_BONUS: int = 10
const CHEST_WIN_GOLD: int = 20
const CHEST_LOSS_GOLD: int = 8
const MERCHANT_BUY_COST: int = 12
const MERCHANT_SELL_GOLD: int = 10
const ALTAR_PRAYER_GOLD: int = 6
const FORGE_COST: int = 10
const FORGE_HELP_GOLD: int = 5
# Tomo: carta épica / perde ouro / o resto é EMBOSCADA (guardiões).
const TOME_CHANCE: float = 0.35
const TOME_LOSS_CHANCE: float = 0.35
const TOME_AMBUSH_BONUS: int = 12
const TOME_LOSS_GOLD: int = 10
const TRAVELER_HELP_COST: int = 5
# Viajante: roubo certo / perde ouro / o resto é EMBOSCADA (era isca).
const TRAVELER_ROB_CHANCE: float = 0.45
const TRAVELER_ROB_LOSS_CHANCE: float = 0.25
const TRAVELER_AMBUSH_BONUS: int = 10
# Acampamento: vasculhar dá carta, senão EMBOSCADA; montar a emboscada é duelo garantido.
const CAMP_SEARCH_CHANCE: float = 0.6
const CAMP_SEARCH_AMBUSH_BONUS: int = 8
const CAMP_SETUP_BONUS: int = 14
const TRAVELER_ROB_GOLD: int = 15
const TRAVELER_ROB_LOSS: int = 10
const MIN_DECK_FOR_SACRIFICE: int = 3

var hud_bar: HUDBar
var inventory_ui: InventoryUI
var card_tooltip: ActionCardTooltip
var rule_tooltip: RuleCardTooltip
var discard_modal: RuleDiscardModal

var title_label: Label
var text_label: Label
var gold_label: Label
var status_label: Label
var preview_hbox: HBoxContainer
var choices_box: HBoxContainer
var leave_btn: Button
var art_frame: Control
var art_layer: Control
var art_rect: TextureRect
var art_has_texture: bool = false
var dim_rect: ColorRect
var flash_rect: ColorRect
var wheel: LuckWheel
var panel_ref: PanelContainer
var luck_spinning: bool = false

var event: Dictionary = {}
var resolved: bool = false
# Desfecho que termina em duelo: "" | "ambushed" | "setup" (ver RunManager.ambush_kind).
var pending_ambush_kind: String = ""
var pending_ambush_bonus: int = 0

# Se definido (testes/depuração), força este evento em vez de sortear.
static var forced_event_id: String = ""
# Idem: força o resultado do sorteio (0..1) em vez de randf() — só testes.
static var forced_roll: float = -1.0
# Pula a roleta/animações (testes).
static var skip_animations: bool = false

func _roll() -> float:
	return forced_roll if forced_roll >= 0.0 else randf()

func _pct(x: float) -> int:
	return int(round(x * 100.0))

func _ready() -> void:
	_setup_ui()
	event = _pick_event()
	_show_event()

# ==========================================
# DADOS DOS EVENTOS
# ==========================================

# Cada escolha: {id, label, hint, requires (opcional): String}.
func _build_events() -> Array[Dictionary]:
	return [
		{
			"id": "chest", "title": "COFRE ENTERRADO",
			"text": "Entre as raízes, um cofre trancado range ao vento. A fechadura parece frágil... ou armada.",
			"choices": [
				{"id": "pry", "label": "ARROMBAR", "hint": "%d%%: +%d ouro  /  %d%%: -%d ouro  /  %d%%: EMBOSCADA" % [_pct(CHEST_WIN_CHANCE), CHEST_WIN_GOLD, _pct(CHEST_NEEDLE_CHANCE), CHEST_LOSS_GOLD, _pct(1.0 - CHEST_WIN_CHANCE - CHEST_NEEDLE_CHANCE)]},
				{"id": "skip", "label": "DEIXAR PRA LÁ", "hint": "Nada acontece"},
			]
		},
		{
			"id": "merchant", "title": "MERCADOR ENCAPUZADO",
			"text": "Uma figura de capuz abre a capa: dentro, cartas embrulhadas em pano. Ela também compra o que você tiver.",
			"choices": [
				{"id": "buy", "label": "COMPRAR (%d ouro)" % MERCHANT_BUY_COST, "hint": "Ganha 1 carta aleatória", "requires": "gold_%d" % MERCHANT_BUY_COST},
				{"id": "sell", "label": "VENDER UMA CARTA", "hint": "Perde 1 carta aleatória do baralho e ganha +%d ouro" % MERCHANT_SELL_GOLD, "requires": "deck_%d" % MIN_DECK_FOR_SACRIFICE},
				{"id": "skip", "label": "RECUSAR", "hint": "Segue viagem"},
			]
		},
		{
			"id": "altar", "title": "ALTAR DAS LEIS",
			"text": "Um altar de pedra, gasto pelo tempo, pede uma oferenda. Em troca, uma Lei antiga promete se revelar.",
			"choices": [
				{"id": "offer", "label": "OFERECER UMA CARTA", "hint": "Perde 1 carta aleatória e ganha 1 Lei aleatória", "requires": "deck_%d" % MIN_DECK_FOR_SACRIFICE},
				{"id": "pray", "label": "ORAR EM SILÊNCIO", "hint": "+%d ouro" % ALTAR_PRAYER_GOLD},
			]
		},
		{
			"id": "forge", "title": "FERREIRO ANDARILHO",
			"text": "Ele martela brasas no ar e jura que consegue melhorar qualquer carta. A forja trabalha sozinha, soprando faíscas.",
			"choices": [
				{"id": "forge", "label": "FORJAR (%d ouro)" % FORGE_COST, "hint": "1 carta aleatória sobe de raridade", "requires": "upgradable_%d" % FORGE_COST},
				{"id": "help", "label": "AJUDAR NA FORJA", "hint": "+%d ouro pelo trabalho" % FORGE_HELP_GOLD},
			]
		},
		{
			"id": "library", "title": "BIBLIOTECA ESQUECIDA",
			"text": "Estantes tombadas, páginas soltas no chão. No fundo, um tomo preso por correntes chama a sua atenção.",
			"choices": [
				{"id": "read", "label": "LER COM CALMA", "hint": "Ganha 1 carta (comum ou rara)"},
				{"id": "tome", "label": "ABRIR O TOMO PROIBIDO", "hint": "%d%%: carta épica  /  %d%%: -%d ouro  /  %d%%: EMBOSCADA" % [_pct(TOME_CHANCE), _pct(TOME_LOSS_CHANCE), TOME_LOSS_GOLD, _pct(1.0 - TOME_CHANCE - TOME_LOSS_CHANCE)]},
			]
		},
		{
			"id": "traveler", "title": "VIAJANTE FERIDO",
			"text": "Um viajante está sentado à beira da trilha, com a bolsa aberta e a perna enfaixada. Ele ainda não notou você.",
			"choices": [
				{"id": "help", "label": "AJUDAR (%d ouro)" % TRAVELER_HELP_COST, "hint": "Ganha 1 carta rara ou melhor", "requires": "gold_%d" % TRAVELER_HELP_COST},
				{"id": "rob", "label": "REVISTAR A BOLSA", "hint": "%d%%: +%d ouro  /  %d%%: -%d ouro  /  %d%%: EMBOSCADA" % [_pct(TRAVELER_ROB_CHANCE), TRAVELER_ROB_GOLD, _pct(TRAVELER_ROB_LOSS_CHANCE), TRAVELER_ROB_LOSS, _pct(1.0 - TRAVELER_ROB_CHANCE - TRAVELER_ROB_LOSS_CHANCE)]},
				{"id": "skip", "label": "IGNORAR", "hint": "Segue viagem"},
			]
		},
		{
			"id": "camp", "title": "ACAMPAMENTO ABANDONADO",
			"text": "Brasas ainda mornas, mochilas jogadas, nenhum sinal de ninguém. Fácil demais para ser verdade.",
			"choices": [
				{"id": "search", "label": "VASCULHAR AS MOCHILAS", "hint": "%d%%: 1 carta (comum ou rara)  /  %d%%: EMBOSCADA (+%d ouro se vencer)" % [_pct(CAMP_SEARCH_CHANCE), _pct(1.0 - CAMP_SEARCH_CHANCE), CAMP_SEARCH_AMBUSH_BONUS]},
				{"id": "setup", "label": "ARMAR UMA EMBOSCADA", "hint": "Duelo garantido, com o inimigo desprevenido (1 carta a menos). Vitória: +%d ouro" % CAMP_SETUP_BONUS},
				{"id": "skip", "label": "CONTORNAR", "hint": "Segue viagem"},
			]
		},
	]

func _pick_event() -> Dictionary:
	var all = _build_events()
	if forced_event_id != "":
		for e in all:
			if e["id"] == forced_event_id:
				return e
	var seen: Array = RunManager.seen_event_ids
	var pool = all.filter(func(e): return not seen.has(e["id"]))
	if pool.is_empty():
		seen.clear()
		pool = all
	var chosen: Dictionary = pool[randi() % pool.size()]
	seen.append(chosen["id"])
	return chosen

# Escolha disponível? (ouro, tamanho do baralho, cartas que podem subir de raridade).
func _requirement_met(req: String) -> bool:
	if req == "":
		return true
	var parts = req.split("_")
	var kind: String = parts[0]
	var amount: int = int(parts[1])
	match kind:
		"gold":
			return RunManager.gold >= amount
		"deck":
			return RunManager.player_deck.size() >= amount
		"upgradable":
			return RunManager.gold >= amount and not _upgradable_cards().is_empty()
	return true

func _requirement_text(req: String) -> String:
	var parts = req.split("_")
	match parts[0]:
		"gold": return "Ouro insuficiente"
		"deck": return "Poucas cartas"
		"upgradable": return "Sem ouro ou sem carta para melhorar"
	return ""

# ==========================================
# UI
# ==========================================

const ART_SIZE: Vector2 = Vector2(960, 440)
const ART_DIR: String = "res://assets/sprites/events/"
const EVENT_TINTS := {
	"chest": Color("#6b4a2a"), "merchant": Color("#4a3a6b"), "altar": Color("#3f6f8a"),
	"forge": Color("#8a4a2a"), "library": Color("#4a5a7a"), "traveler": Color("#5a6a3a"),
	"camp": Color("#6a3a3a"),
}

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "EventUILayer"
	canvas.layer = 70
	add_child(canvas)

	add_child(BiomeBackground.new())

	hud_bar = HUDBar.new()
	canvas.add_child(hud_bar)
	hud_bar.open_laws_requested.connect(func(): inventory_ui.open_on_tab(InventoryUI.Tab.LAWS))
	hud_bar.open_cards_requested.connect(func(): inventory_ui.open_on_tab(InventoryUI.Tab.CARDS))

	inventory_ui = InventoryUI.new()
	add_child(inventory_ui)
	inventory_ui.setup()

	discard_modal = RuleDiscardModal.new()
	discard_modal.rule_replaced.connect(_on_reward_law_replaced)
	discard_modal.replacement_canceled.connect(_on_reward_law_declined)
	add_child(discard_modal)

	rule_tooltip = RuleCardTooltip.new()
	add_child(rule_tooltip)
	card_tooltip = ActionCardTooltip.new()
	add_child(card_tooltip)

	# Centralizado, mas deslocado pra direita pra não ficar sob o HUD lateral.
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 150)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(margin)

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.09, 0.1, 0.14, 0.97), Color(0.55, 0.4, 0.8), 18))
	margin.add_child(panel)

	var content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 10)
	content_box.custom_minimum_size = Vector2(ART_SIZE.x, 0)
	panel.add_child(content_box)

	var head = HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	content_box.add_child(head)
	var kicker = Label.new()
	kicker.text = "? ENCONTRO ?"
	kicker.add_theme_font_size_override("font_size", 24)
	kicker.add_theme_color_override("font_color", Color(0.7, 0.55, 0.95))
	head.add_child(kicker)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 46)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title_label.add_theme_constant_override("outline_size", 8)
	head.add_child(title_label)

	# --- Moldura da arte: imagem do evento (ou placeholder) + camadas de efeito ---
	art_frame = Control.new()
	art_frame.custom_minimum_size = ART_SIZE
	art_frame.clip_contents = true
	content_box.add_child(art_frame)
	art_layer = Control.new()
	art_layer.size = ART_SIZE
	art_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(art_layer)
	art_layer.draw.connect(_draw_art_placeholder)
	art_rect = TextureRect.new()
	art_rect.size = ART_SIZE
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_SCALE
	art_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_layer.add_child(art_rect)

	var frame_line = Panel.new()
	frame_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fl = StyleBoxFlat.new()
	fl.bg_color = Color(0, 0, 0, 0)
	fl.set_border_width_all(4)
	fl.border_color = Color("#d9a441")
	frame_line.add_theme_stylebox_override("panel", fl)
	art_frame.add_child(frame_line)

	gold_label = Label.new()
	gold_label.position = Vector2(14, 8)
	gold_label.add_theme_font_size_override("font_size", 26)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	gold_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	gold_label.add_theme_constant_override("outline_size", 6)
	art_frame.add_child(gold_label)

	dim_rect = ColorRect.new()
	dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_rect.color = Color(0.05, 0.03, 0.08, 0.72)
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_rect.modulate.a = 0.0
	art_frame.add_child(dim_rect)

	preview_hbox = HBoxContainer.new()
	preview_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_hbox.add_theme_constant_override("separation", 24)
	preview_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(preview_hbox)

	wheel = LuckWheel.new()
	wheel.position = (ART_SIZE - wheel.size) / 2.0
	wheel.visible = false
	art_frame.add_child(wheel)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color.WHITE
	flash_rect.modulate.a = 0.0
	art_frame.add_child(flash_rect)

	# --- Texto + escolhas ---
	text_label = Label.new()
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(ART_SIZE.x - 40, 0)
	text_label.add_theme_font_size_override("font_size", 26)
	text_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	content_box.add_child(text_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(ART_SIZE.x - 40, 0)
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.65))
	status_label.visible = false
	content_box.add_child(status_label)

	choices_box = HBoxContainer.new()
	choices_box.alignment = BoxContainer.ALIGNMENT_CENTER
	choices_box.add_theme_constant_override("separation", 12)
	content_box.add_child(choices_box)

	leave_btn = Button.new()
	leave_btn.text = "SEGUIR VIAGEM"
	leave_btn.custom_minimum_size = Vector2(340, 60)
	leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave_btn.add_theme_font_size_override("font_size", 26)
	PixelUI.skin_button(leave_btn, Color(0.4, 0.7, 0.9), "", "icone_mapa")
	leave_btn.pressed.connect(_on_leave_pressed)
	leave_btn.visible = false
	content_box.add_child(leave_btn)

	panel_ref = panel

func _load_art() -> void:
	var path = ART_DIR + String(event["id"]) + ".png"
	art_rect.texture = load(path) if ResourceLoader.exists(path) else null
	art_has_texture = art_rect.texture != null
	art_layer.queue_redraw()

# Placeholder (até existir assets/sprites/events/<id>.png): bandas na cor do evento.
func _draw_art_placeholder() -> void:
	if art_has_texture or event.is_empty():
		return
	var base: Color = EVENT_TINTS.get(event["id"], Color("#3a2b41"))
	var bands = 12
	for i in range(bands):
		var t = float(i) / bands
		art_layer.draw_rect(Rect2(0, t * ART_SIZE.y, ART_SIZE.x, ART_SIZE.y / bands + 1), base.darkened(0.55).lerp(base.lightened(0.1), t))
	var font = ThemeDB.fallback_font
	art_layer.draw_string(font, Vector2(0, ART_SIZE.y / 2.0 - 10), String(event["title"]), HORIZONTAL_ALIGNMENT_CENTER, ART_SIZE.x, 54, Color(1, 1, 1, 0.22))
	art_layer.draw_string(font, Vector2(0, ART_SIZE.y / 2.0 + 34), "[ arte do evento: %s%s.png  -  320x144 ]" % [ART_DIR.trim_prefix("res://"), event["id"]], HORIZONTAL_ALIGNMENT_CENTER, ART_SIZE.x, 22, Color(1, 1, 1, 0.35))

func _show_event() -> void:
	title_label.text = event["title"]
	text_label.text = event["text"]
	text_label.visible = true
	status_label.text = ""
	status_label.visible = false
	_load_art()
	_refresh_gold_label()

	for child in choices_box.get_children():
		child.queue_free()
	var n: int = event["choices"].size()
	var btn_w: float = (ART_SIZE.x - 12.0 * (n - 1)) / n
	for choice in event["choices"]:
		var req: String = choice.get("requires", "")
		var available = _requirement_met(req)
		var btn = Button.new()
		btn.text = "%s\n%s" % [choice["label"], choice["hint"] if available else _requirement_text(req)]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(btn_w, 130)
		btn.add_theme_font_size_override("font_size", 21)
		PixelUI.skin_button(btn, _choice_color(choice["id"]))
		btn.disabled = not available
		btn.pressed.connect(_on_choice_pressed.bind(choice["id"]))
		choices_box.add_child(btn)

func _choice_color(choice_id: String) -> Color:
	match choice_id:
		"skip": return Color(0.45, 0.45, 0.5)
		"pry", "tome", "rob", "search": return Color(0.9, 0.5, 0.3)
		"setup": return Color(0.85, 0.35, 0.35)
		_: return Color(0.4, 0.85, 0.5)

func _refresh_gold_label() -> void:
	gold_label.text = "Ouro: %d" % RunManager.gold
	if hud_bar != null:
		hud_bar.update_gold()
		hud_bar.refresh_cards_inventory_count()

# ==========================================
# SORTE (roleta)
# ==========================================

# Escolhas de sorte -> fatias da roleta (a ordem define o sorteio cumulativo).
func _luck_segments(event_id: String, choice_id: String) -> Array:
	match event_id + "." + choice_id:
		"chest.pry":
			return [
				{"key": "win", "chance": CHEST_WIN_CHANCE, "label": "+%d OURO" % CHEST_WIN_GOLD, "kind": "good"},
				{"key": "needle", "chance": CHEST_NEEDLE_CHANCE, "label": "-%d OURO" % CHEST_LOSS_GOLD, "kind": "bad"},
				{"key": "ambush", "chance": 1.0 - CHEST_WIN_CHANCE - CHEST_NEEDLE_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"library.tome":
			return [
				{"key": "epic", "chance": TOME_CHANCE, "label": "CARTA ÉPICA", "kind": "good"},
				{"key": "loss", "chance": TOME_LOSS_CHANCE, "label": "-%d OURO" % TOME_LOSS_GOLD, "kind": "bad"},
				{"key": "ambush", "chance": 1.0 - TOME_CHANCE - TOME_LOSS_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"traveler.rob":
			return [
				{"key": "win", "chance": TRAVELER_ROB_CHANCE, "label": "+%d OURO" % TRAVELER_ROB_GOLD, "kind": "good"},
				{"key": "loss", "chance": TRAVELER_ROB_LOSS_CHANCE, "label": "-%d OURO" % TRAVELER_ROB_LOSS, "kind": "bad"},
				{"key": "ambush", "chance": 1.0 - TRAVELER_ROB_CHANCE - TRAVELER_ROB_LOSS_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"camp.search":
			return [
				{"key": "card", "chance": CAMP_SEARCH_CHANCE, "label": "CARTA", "kind": "good"},
				{"key": "ambush", "chance": 1.0 - CAMP_SEARCH_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
	return []

# Sorteia a fatia (usa _roll(), então forced_roll continua valendo nos testes).
func _pick_outcome(segments: Array) -> String:
	var r: float = _roll()
	var acc := 0.0
	for s in segments:
		acc += float(s["chance"])
		if r < acc:
			return s["key"]
	return segments[segments.size() - 1]["key"]

func _on_choice_pressed(choice_id: String) -> void:
	if resolved:
		return
	resolved = true
	choices_box.visible = false
	for child in preview_hbox.get_children():
		child.queue_free()
	var segments = _luck_segments(event["id"], choice_id)
	if segments.is_empty():
		_finish_choice(choice_id, "")
		return
	var outcome = _pick_outcome(segments)
	if skip_animations:
		_finish_choice(choice_id, outcome)
		return
	_play_luck(choice_id, segments, outcome)

func _play_luck(choice_id: String, segments: Array, outcome: String) -> void:
	text_label.text = "A sorte está lançada..."
	text_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	var dim_tween = create_tween()
	dim_tween.tween_property(dim_rect, "modulate:a", 1.0, 0.25)
	wheel.setup(segments)
	wheel.visible = true
	wheel.scale = Vector2.ONE * 0.2
	wheel.pivot_offset = wheel.size / 2.0
	var pop = create_tween()
	pop.tween_property(wheel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	luck_spinning = true
	wheel.spin_to(outcome)
	await wheel.finished
	luck_spinning = false
	var kind: String = "neutral"
	for s in segments:
		if s["key"] == outcome:
			kind = s.get("kind", "neutral")
	_impact(kind)
	await get_tree().create_timer(0.5).timeout
	var out = create_tween()
	out.set_parallel(true)
	out.tween_property(wheel, "scale", Vector2.ONE * 0.2, 0.25)
	out.tween_property(wheel, "modulate:a", 0.0, 0.25)
	await out.finished
	wheel.visible = false
	wheel.modulate.a = 1.0
	text_label.remove_theme_color_override("font_color")
	text_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	_finish_choice(choice_id, outcome)

# Flash colorido + tremor da arte conforme o tipo do desfecho.
func _impact(kind: String) -> void:
	var col: Color = LuckWheel.KIND_COLORS.get(kind, Color.WHITE)
	flash_rect.color = col.lightened(0.3)
	var f = create_tween()
	f.tween_property(flash_rect, "modulate:a", 0.55 if kind == "danger" else 0.35, 0.05)
	f.tween_property(flash_rect, "modulate:a", 0.0, 0.5)
	var amp: float = 16.0 if kind == "danger" else (8.0 if kind == "bad" else 4.0)
	var s = create_tween()
	for i in range(8):
		s.tween_property(art_layer, "position", Vector2(randf_range(-amp, amp), randf_range(-amp, amp)) * (1.0 - i / 8.0), 0.04)
	s.tween_property(art_layer, "position", Vector2.ZERO, 0.04)

func _input(e: InputEvent) -> void:
	if luck_spinning and e is InputEventMouseButton and e.pressed:
		wheel.skip()

func _finish_choice(choice_id: String, outcome: String) -> void:
	status_label.text = _resolve(event["id"], choice_id, outcome)
	text_label.visible = false
	status_label.visible = true
	_refresh_gold_label()
	if not preview_hbox.get_children().is_empty():
		dim_rect.modulate.a = 1.0
	else:
		dim_rect.modulate.a = 0.0
	leave_btn.visible = true
	if pending_ambush_kind != "":
		leave_btn.text = "LUTAR!"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45) if pending_ambush_kind == "ambushed" else Color(0.6, 0.95, 0.65))
		PixelUI.skin_button(leave_btn, Color(0.9, 0.3, 0.3), "", "icone_mapa")

# ==========================================
# RESOLUÇÃO
# ==========================================

# Devolve o texto do desfecho; cartas/Leis envolvidas aparecem em preview_hbox.
func _resolve(event_id: String, choice_id: String, outcome: String = "") -> String:
	if choice_id == "skip":
		return "Você segue seu caminho."
	match event_id:
		"chest":
			if outcome == "win":
				RunManager.add_gold(CHEST_WIN_GOLD)
				return "Clique! O cofre se abre: +%d de ouro." % CHEST_WIN_GOLD
			if outcome == "needle":
				return "Uma agulha envenenada! Você perde %d de ouro correndo atrás do antídoto." % _lose_gold(CHEST_LOSS_GOLD)
			return _start_ambush("ambushed", CHEST_AMBUSH_BONUS, "A fechadura era um alarme! Guardas saem de trás das árvores.")
		"merchant":
			if choice_id == "buy":
				RunManager.spend_gold(MERCHANT_BUY_COST)
				return "Você paga %d de ouro. %s" % [MERCHANT_BUY_COST, _give_card(_random_card(ActionCard.Rarity.COMMON), "RECEBIDA")]
			var lost = _take_random_card()
			if lost != null:
				RunManager.add_gold(MERCHANT_SELL_GOLD)
				preview_hbox.add_child(_labeled_card_visual("VENDIDA", lost, Color(1.0, 0.6, 0.6, 0.8)))
				return "Vendida por %d de ouro." % MERCHANT_SELL_GOLD
			return "O mercador não se interessa por nada que você tem."
		"altar":
			if choice_id == "pray":
				RunManager.add_gold(ALTAR_PRAYER_GOLD)
				return "A pedra esquenta sob suas mãos: +%d de ouro." % ALTAR_PRAYER_GOLD
			var offered = _take_random_card()
			if offered != null:
				preview_hbox.add_child(_labeled_card_visual("OFERECIDA", offered, Color(1.0, 0.6, 0.6, 0.8)))
			return "O altar aceita a oferenda. %s" % _give_random_law()
		"forge":
			if choice_id == "help":
				RunManager.add_gold(FORGE_HELP_GOLD)
				return "Você acende os foles por uma hora: +%d de ouro." % FORGE_HELP_GOLD
			return _forge_card()
		"library":
			if choice_id == "read":
				return _give_card(_random_card(ActionCard.Rarity.COMMON, ActionCard.Rarity.RARE), "ENCONTRADA")
			if outcome == "epic":
				return "As correntes se soltam sozinhas! %s" % _give_card(_random_card(ActionCard.Rarity.EPIC), "ENCONTRADA")
			if outcome == "loss":
				return "O tomo morde de volta: tinta preta nos dedos e %d de ouro a menos." % _lose_gold(TOME_LOSS_GOLD)
			return _start_ambush("ambushed", TOME_AMBUSH_BONUS, "As estantes se movem: os guardiões da biblioteca despertam!")
		"traveler":
			if choice_id == "help":
				RunManager.spend_gold(TRAVELER_HELP_COST)
				return "Ele agradece e te entrega algo da bolsa. %s" % _give_card(_random_card(ActionCard.Rarity.RARE), "PRESENTE")
			if outcome == "win":
				RunManager.add_gold(TRAVELER_ROB_GOLD)
				return "Ele dormia pesado. Você sai com +%d de ouro." % TRAVELER_ROB_GOLD
			if outcome == "loss":
				return "Ele estava acordado! Você larga %d de ouro na pressa." % _lose_gold(TRAVELER_ROB_LOSS)
			return _start_ambush("ambushed", TRAVELER_AMBUSH_BONUS, "O viajante assobia: era isca! Bandidos cercam a trilha.")
		"camp":
			if choice_id == "setup":
				return _start_ambush("setup", CAMP_SETUP_BONUS, "Você se esconde entre as barracas. Quando o bando volta, é você quem ataca primeiro.")
			if outcome == "card":
				return _give_card(_random_card(ActionCard.Rarity.COMMON, ActionCard.Rarity.RARE), "ENCONTRADA")
			return _start_ambush("ambushed", CAMP_SEARCH_AMBUSH_BONUS, "Uma corda estala: era armadilha! O bando surge de todos os lados.")
	return ""

# Marca o desfecho como duelo (o botão vira "LUTAR!"); devolve o texto da cena.
func _start_ambush(kind: String, bonus_gold: int, flavor: String) -> String:
	pending_ambush_kind = kind
	pending_ambush_bonus = bonus_gold
	return flavor

# Perde até `amount` de ouro (nunca abaixo de 0); devolve o quanto perdeu de verdade.
func _lose_gold(amount: int) -> int:
	var real = mini(amount, RunManager.gold)
	RunManager.gold -= real
	return real

# Sorteia uma carta com raridade entre min e max (padrão: até a mais alta).
func _random_card(min_rarity: int, max_rarity: int = ActionCard.Rarity.LEGENDARY) -> ActionCard:
	var pool = LootTables.get_all_action_cards().filter(func(c): return c.rarity >= min_rarity and c.rarity <= max_rarity)
	if pool.is_empty():
		pool = LootTables.get_all_action_cards()
	return LootTables.pick_weighted_actions(pool, 1)[0]

# Adiciona a carta ao baralho; se estiver cheio, vira ouro (metade do preço).
func _give_card(card: ActionCard, caption: String) -> String:
	preview_hbox.add_child(_labeled_card_visual(caption, card, Color(1.2, 1.15, 0.85)))
	if RunManager.add_card_to_deck(card):
		return "Você ganhou uma carta:"
	var compensation = int(card.cost_gold / 2.0)
	RunManager.add_gold(compensation)
	return "Seu baralho está cheio, então ela vira +%d de ouro." % compensation

func _take_random_card() -> ActionCard:
	if RunManager.player_deck.is_empty():
		return null
	var card: ActionCard = RunManager.player_deck[randi() % RunManager.player_deck.size()]
	RunManager.player_deck.erase(card)
	return card

func _upgradable_cards() -> Array:
	return RunManager.player_deck.filter(func(c: ActionCard): return c.rarity < ActionCard.Rarity.LEGENDARY)

func _forge_card() -> String:
	var candidates = _upgradable_cards()
	if candidates.is_empty():
		return "Não há nada que ele possa melhorar."
	RunManager.spend_gold(FORGE_COST)
	var old_card: ActionCard = candidates[randi() % candidates.size()]
	var target_rarity = old_card.rarity + 1
	var pool = LootTables.get_all_action_cards().filter(func(c): return c.rarity == target_rarity and c.id != old_card.id)
	if pool.is_empty():
		return "A forja esfria sem resultado. Seu ouro é devolvido."
	var upgraded: ActionCard = pool[randi() % pool.size()]
	var idx = RunManager.player_deck.find(old_card)
	RunManager.player_deck[idx] = upgraded
	preview_hbox.add_child(_labeled_card_visual("ANTES", old_card, Color(1.0, 0.7, 0.7, 0.85)))
	var arrow = Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 46)
	arrow.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	preview_hbox.add_child(arrow)
	preview_hbox.add_child(_labeled_card_visual("DEPOIS", upgraded, Color(1.2, 1.15, 0.85)))
	return "A carta sai da forja transformada (-%d de ouro):" % FORGE_COST

func _give_random_law() -> String:
	var owned_ids: Array[String] = []
	for r in RunManager.active_rules:
		owned_ids.append(r.id)
	var pool = LootTables.get_all_rules().filter(func(r: RuleCard): return not owned_ids.has(r.id))
	if pool.is_empty():
		RunManager.add_gold(10)
		return "Você já conhece todas as Leis: o altar devolve +10 de ouro."
	var rule: RuleCard = LootTables.pick_weighted_rules(pool, 1)[0]
	if RunManager.add_rule(rule):
		preview_hbox.add_child(_labeled_law_visual("NOVA LEI", rule, Color(1.2, 1.15, 0.85)))
		return "Uma Lei se revela:"
	# Limite de Leis: o jogador escolhe qual revogar.
	discard_modal.prompt_replace(rule)
	return "Suas Leis estão lotadas: escolha qual revogar."

func _on_reward_law_replaced(_old: RuleCard, new_rule: RuleCard) -> void:
	status_label.text = "Uma Lei se revela:"
	preview_hbox.add_child(_labeled_law_visual("NOVA LEI", new_rule, Color(1.2, 1.15, 0.85)))

func _on_reward_law_declined() -> void:
	status_label.text = "Você recusou a Lei oferecida."

func _on_leave_pressed() -> void:
	if pending_ambush_kind != "":
		# Escaramuça 6x6 forçada; ao vencer, volta pro mapa (nó do "?" já consumido).
		RunManager.ambush_kind = pending_ambush_kind
		RunManager.ambush_bonus_gold = pending_ambush_bonus
		RunManager.current_node_type = MapNode.NodeType.Duelo
		RunManager.current_board_size = RunManager.AMBUSH_BOARD_SIZE
		get_tree().call_deferred("change_scene_to_file", "res://main.tscn")
		return
	get_tree().call_deferred("change_scene_to_file", MAP_SCENE_PATH)

# Pré-visualizações (mesmo padrão da BetView).
func _labeled_card_visual(caption: String, card: ActionCard, tint: Color) -> Control:
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var label = Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(label)
	var visual = ActionCardVisual.new(card, true, PREVIEW_SCALE)
	visual.modulate = tint
	visual.mouse_filter = Control.MOUSE_FILTER_STOP
	visual.mouse_entered.connect(func():
		if card_tooltip:
			card_tooltip.show_tooltip(card, visual.global_position + Vector2(visual.custom_minimum_size.x / 2.0, 0.0))
	)
	visual.mouse_exited.connect(func():
		if card_tooltip:
			card_tooltip.hide_tooltip()
	)
	box.add_child(visual)
	return box

func _labeled_law_visual(caption: String, rule: RuleCard, tint: Color) -> Control:
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var label = Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(label)
	var visual = RuleCardVisual.new(rule, null, true, PREVIEW_SCALE)
	visual.modulate = tint
	visual.mouse_filter = Control.MOUSE_FILTER_STOP
	visual.mouse_entered.connect(func():
		if rule_tooltip:
			rule_tooltip.show_tooltip(rule, visual.global_position + Vector2(visual.custom_minimum_size.x / 2.0, 0.0))
	)
	visual.mouse_exited.connect(func():
		if rule_tooltip:
			rule_tooltip.hide_tooltip()
	)
	box.add_child(visual)
	return box
