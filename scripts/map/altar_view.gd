class_name AltarView
extends Control

# Nó "Altar de Leis" do mapa: um santuário que mexe nas LEIS da run (que ficam
# ativas até o fim). Uma única ação por visita:
#   RATIFICAR : escolhe 1 entre 3 Leis ainda desconhecidas (grátis).
#   TROCAR    : sacrifica uma Lei sua (paga ouro) e escolhe 1 entre 3 Leis da
#               MESMA categoria (controle de build sem depender só da sorte).
# Mesmo esqueleto visual do EventView/BetView: fundo de bioma, HUD lateral,
# inventário, tooltips, e o modal de revogar quando as Leis estão lotadas.

const MAP_SCENE_PATH: String = "res://map_view.tscn"
const ART_PATH: String = "res://assets/sprites/events/altar_leis.png"
const SWAP_COST: int = 10
const OFFER_COUNT: int = 3
const OFFER_SCALE: float = 1.0
const SACRIFICE_SCALE: float = 0.5
const CHOICE_W: float = 450.0
const ART_SIZE: Vector2 = Vector2(900, 405)
const MAX_TEXT_H: float = 190.0
const MIN_TEXT_FONT: int = 22

const C_GOLD := Color("#d9a441")
const C_CREAM := Color("#efe6cf")

enum Stage { MENU, OFFERS, SACRIFICE, DONE }

var hud_bar: HUDBar
var inventory_ui: InventoryUI
var rule_tooltip: RuleCardTooltip
var discard_modal: RuleDiscardModal

var title_label: Label
var text_label: Label
var body: Control            # área que muda a cada etapa
var leave_btn: Button

var stage: int = Stage.MENU
var sacrificed: RuleCard = null   # Lei escolhida para trocar (null = ratificar)
var used: bool = false

func _ready() -> void:
	_setup_ui()
	_show_menu()

# ==========================================
# UI base
# ==========================================
func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "AltarUILayer"
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
	discard_modal.rule_replaced.connect(_on_offer_replaced)
	discard_modal.replacement_canceled.connect(func(): _set_text("Você recusou a Lei oferecida. Escolha outra ou volte."))
	add_child(discard_modal)

	rule_tooltip = RuleCardTooltip.new()
	add_child(rule_tooltip)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 470)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.09, 0.1, 0.14, 0.97), Color(0.55, 0.4, 0.8), 18))
	margin.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(ART_SIZE.x + CHOICE_W + 16, 0)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	box.add_child(head)
	var kicker := Label.new()
	kicker.text = "SANTUARIO"
	kicker.add_theme_font_size_override("font_size", 24)
	kicker.add_theme_color_override("font_color", Color(0.7, 0.55, 0.95))
	head.add_child(kicker)
	title_label = Label.new()
	title_label.text = "ALTAR DAS LEIS"
	title_label.add_theme_font_size_override("font_size", 46)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title_label.add_theme_constant_override("outline_size", 8)
	head.add_child(title_label)

	text_label = Label.new()
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.custom_minimum_size = Vector2(ART_SIZE.x + CHOICE_W - 40, 0)
	text_label.add_theme_font_size_override("font_size", 40)
	text_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	box.add_child(text_label)

	# Corpo: muda a cada etapa (menu / ofertas / sacrifício / resultado).
	body = VBoxContainer.new()
	body.custom_minimum_size = Vector2(ART_SIZE.x + CHOICE_W + 16, ART_SIZE.y)
	box.add_child(body)

	leave_btn = Button.new()
	leave_btn.text = "SEGUIR VIAGEM"
	leave_btn.custom_minimum_size = Vector2(CHOICE_W, 72)
	leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave_btn.add_theme_font_size_override("font_size", 32)
	PixelUI.skin_button(leave_btn, Color(0.4, 0.7, 0.9), "", "icone_mapa")
	leave_btn.pressed.connect(func(): SceneTransition.go(MAP_SCENE_PATH))
	leave_btn.visible = false
	box.add_child(leave_btn)

# Texto com quebra manual + fonte que encolhe se for longo (mesma regra do EventView).
func _set_text(text: String) -> void:
	text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var width := text_label.custom_minimum_size.x
	var font: Font = text_label.get_theme_font("font")
	var size := 40
	var wrapped := _wrap(font, text, width, size)
	while size > MIN_TEXT_FONT and font.get_multiline_string_size(wrapped, HORIZONTAL_ALIGNMENT_CENTER, -1, size).y > MAX_TEXT_H:
		size -= 2
		wrapped = _wrap(font, text, width, size)
	text_label.add_theme_font_size_override("font_size", size)
	text_label.text = wrapped

func _wrap(font: Font, text: String, width: float, size: int) -> String:
	var out: Array[String] = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return "\n".join(out)

func _clear_body() -> void:
	for c in body.get_children():
		c.queue_free()

func _choice_button(label: String, hint: String, accent: Color, disabled: bool = false) -> Button:
	var btn := Button.new()
	btn.text = "%s\n%s" % [label, hint]
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.custom_minimum_size = Vector2(CHOICE_W, 0)
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 34)
	PixelUI.skin_button(btn, accent)
	btn.disabled = disabled
	return btn

func _small_button(text: String, accent: Color, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 56)
	b.add_theme_font_size_override("font_size", 26)
	PixelUI.skin_button(b, accent)
	return b

# ==========================================
# Etapas
# ==========================================
func _show_menu() -> void:
	stage = Stage.MENU
	sacrificed = null
	_clear_body()
	leave_btn.visible = false
	_set_text("Um altar de pedra guarda as Leis do reino. Ele aceita uma só vez: ratifique uma Lei nova ou troque uma das suas.")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)

	var art := TextureRect.new()
	art.custom_minimum_size = ART_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(ART_PATH):
		art.texture = load(ART_PATH)
	row.add_child(art)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fl := StyleBoxFlat.new()
	fl.bg_color = Color(0, 0, 0, 0)
	fl.set_border_width_all(4)
	fl.border_color = C_GOLD
	frame.add_theme_stylebox_override("panel", fl)
	art.add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(CHOICE_W, ART_SIZE.y)
	row.add_child(col)

	var have_offers := not _offer_pool().is_empty()
	var rat := _choice_button("RATIFICAR UMA LEI", "Escolha 1 entre %d Leis novas. Grátis." % OFFER_COUNT if have_offers else "Você já conhece todas as Leis.", Color(0.3, 0.9, 0.4), not have_offers)
	rat.pressed.connect(_on_ratify)
	col.add_child(rat)

	var can_swap := not RunManager.active_rules.is_empty() and RunManager.gold >= SWAP_COST
	var hint := "Sacrifique uma Lei sua (%d ouro) e escolha outra da mesma categoria." % SWAP_COST
	if RunManager.active_rules.is_empty():
		hint = "Você não tem Leis para trocar."
	elif RunManager.gold < SWAP_COST:
		hint = "Faltam %d ouro." % (SWAP_COST - RunManager.gold)
	var swp := _choice_button("TROCAR UMA LEI", hint, Color(0.85, 0.64, 0.25), not can_swap)
	swp.pressed.connect(_on_swap)
	col.add_child(swp)

	var skip := _choice_button("DEIXAR O ALTAR", "Segue viagem sem mudar nada.", Color.WHITE)
	skip.pressed.connect(func(): SceneTransition.go(MAP_SCENE_PATH))
	col.add_child(skip)

# Leis que o altar pode oferecer: liberadas na meta e que o jogador ainda não tem.
func _offer_pool(category: int = -1) -> Array[RuleCard]:
	var owned: Array[String] = []
	for r in RunManager.active_rules:
		owned.append(r.id)
	if sacrificed != null:
		owned.append(sacrificed.id)
	var pool: Array[RuleCard] = []
	for r in LootTables.get_player_rules():
		if owned.has(r.id):
			continue
		if category >= 0 and r.category != category:
			continue
		pool.append(r)
	return pool

func _on_ratify() -> void:
	sacrificed = null
	_show_offers()

func _on_swap() -> void:
	_show_sacrifice()

# Etapa: escolher qual Lei sua sacrificar.
func _show_sacrifice() -> void:
	stage = Stage.SACRIFICE
	_clear_body()
	_set_text("Qual Lei você sacrifica? O altar oferecerá outra da mesma categoria. Custa %d de ouro." % SWAP_COST)
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 12)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(flow)
	for rule in RunManager.active_rules:
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", 8)
		var vis := RuleCardVisual.new(rule, rule_tooltip, true, SACRIFICE_SCALE)
		wrap.add_child(vis)
		var has_offer := not _offer_pool(rule.category).is_empty()
		var b := _small_button("SACRIFICAR" if has_offer else "SEM OFERTA", Color(0.9, 0.35, 0.35), RuleCardVisual.CARD_SIZE * SACRIFICE_SCALE)
		b.disabled = not has_offer
		b.pressed.connect(func():
			sacrificed = rule
			_show_offers())
		wrap.add_child(b)
		flow.add_child(wrap)
	var back := _small_button("VOLTAR", Color.WHITE, 220)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_show_menu)
	body.add_child(back)

# Etapa: 3 Leis para escolher (qualquer categoria ao ratificar; a mesma da
# sacrificada ao trocar).
func _show_offers() -> void:
	stage = Stage.OFFERS
	_clear_body()
	var cat: int = sacrificed.category if sacrificed != null else -1
	var pool := _offer_pool(cat)
	var offers: Array[RuleCard] = LootTables.pick_weighted_rules(pool, OFFER_COUNT)
	if offers.is_empty():
		_set_text("O altar não tem nenhuma Lei nova para oferecer.")
		_show_menu_back_button()
		return
	if sacrificed != null:
		_set_text("Em troca de %s, o altar oferece:" % sacrificed.name)
	else:
		_set_text("Escolha uma Lei para ratificar.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	for i in range(offers.size()):
		var rule: RuleCard = offers[i]
		var wrap := VBoxContainer.new()
		wrap.alignment = BoxContainer.ALIGNMENT_CENTER
		wrap.add_theme_constant_override("separation", 10)
		var vis := RuleCardVisual.new(rule, rule_tooltip, false, OFFER_SCALE)
		wrap.add_child(vis)
		var pick := _small_button("RATIFICAR", Color(0.3, 0.9, 0.4), RuleCardVisual.CARD_SIZE * OFFER_SCALE)
		pick.pressed.connect(_on_offer_picked.bind(rule))
		wrap.add_child(pick)
		row.add_child(wrap)
		vis.play_flip_reveal(0.12 + i * 0.14)
	_show_menu_back_button()

func _show_menu_back_button() -> void:
	var back := _small_button("VOLTAR", Color.WHITE, 220)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_show_menu)
	body.add_child(back)

func _on_offer_picked(rule: RuleCard) -> void:
	if sacrificed != null:
		# Troca: remove a Lei antiga (abre vaga), cobra e ratifica a nova.
		if not RunManager.spend_gold(SWAP_COST):
			_set_text("Ouro insuficiente para a troca.")
			return
		RunManager.remove_rule(sacrificed.id)
		RunManager.add_rule(rule)
		_finish("%s foi sacrificada. O altar ratifica:" % sacrificed.name, rule)
		return
	if RunManager.add_rule(rule):
		_finish("O altar ratifica a Lei:", rule)
	else:
		# Leis lotadas: o jogador escolhe qual revogar.
		discard_modal.prompt_replace(rule)

func _on_offer_replaced(_old: RuleCard, new_rule: RuleCard) -> void:
	_finish("A Lei antiga é revogada. O altar ratifica:", new_rule)

# Etapa final: mostra a Lei ganha e libera a saída (uma ação por visita).
func _finish(message: String, rule: RuleCard) -> void:
	stage = Stage.DONE
	used = true
	_clear_body()
	_set_text(message)
	if hud_bar != null:
		hud_bar.update_gold()
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var vis := RuleCardVisual.new(rule, rule_tooltip, false, OFFER_SCALE)
	center.add_child(vis)
	vis.play_flip_reveal(0.1)
	leave_btn.visible = true
	# Juice: fagulhas e pulso quando a Lei é ratificada (depois do flip).
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(vis) and vis.is_inside_tree():
		Juice.sparkle(self, vis.global_position + vis.size * 0.5, 28)
		Juice.pulse(vis, 1.08, 0.3)
