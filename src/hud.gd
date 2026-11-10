extends CanvasLayer
# 幾乎沒有字的 HUD：準星、畫面血、字幕、標題卡、按鍵圖示、筆記頁。
const Icons = preload("res://src/icons.gd")
const St = preload("res://src/combatant.gd").St
var pl                      # 本機玩家 combatant
var foe
var cam: Camera3D
var root: Control
var sub: Label
var sub_name: Label
var title_big: Label
var title_small: Label
var title_bg: ColorRect
var tut: Label
var help: Label
var overlay: ColorRect
var omat: ShaderMaterial
var splats = []
var flash_c = Color(0, 0, 0, 0)
var flash_t = 0.0
var prompt_act = ""
var prompt_pos = Vector3.ZERO
var prompt_world = true
var prompt_t = 0.0
var font: Font
var page = []               # 目前顯示的筆記頁草圖
var page_t = 0.0
var pause_menu: Control
var paused = false
var pause_i = 0
var rounds = []             # 對戰回合圓點
var timer_frac = -1.0
var hide_cross = false
var bugs = 0.0
var smoke = 0.0
var sub_id = 0
var net_warn = false
signal pause_choice(i: int)

const SHADER = """
shader_type canvas_item;
uniform float vig = 0.35;
uniform float red = 0.0;
uniform float grain = 0.05;
uniform float gray = 0.0;
uniform float tunnel = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.0, 0.8));
	float v = smoothstep(0.35, 0.85, d) * vig;
	float n = fract(sin(dot(UV * (1.0 + fract(TIME)), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	float r = smoothstep(0.25, 0.75, d) * red;
	float tn = smoothstep(0.22, 0.34, d) * tunnel;
	COLOR = vec4(mix(vec3(0.0), vec3(0.5, 0.0, 0.0), clamp(r * 1.2, 0.0, 1.0)) + n * grain, clamp(max(max(v, r * 0.85), tn * 0.93) + abs(n) * grain + gray * 0.3, 0.0, 1.0));
}
"""

func _ready() -> void:
	layer = 10; process_mode = Node.PROCESS_MODE_ALWAYS
	font = G.font()
	overlay = ColorRect.new(); overlay.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh = Shader.new(); sh.code = SHADER; omat = ShaderMaterial.new(); omat.shader = sh; overlay.material = omat; add_child(overlay)
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	root.draw.connect(_draw_root)
	title_bg = ColorRect.new(); title_bg.color = Color(0, 0, 0, 0); title_bg.set_anchors_preset(Control.PRESET_FULL_RECT); title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(title_bg)
	title_small = _label(34, Color(0.85, 0.8, 0.7)); _place(title_small, 0.5, 0.5, -600, -170, 600, -120)
	title_big = _label(150, Color(1, 1, 1)); _place(title_big, 0.5, 0.5, -640, -120, 640, 90)
	sub_name = _label(22, Color(0.95, 0.78, 0.4)); _place(sub_name, 0.5, 1.0, -500, -178, 500, -148)
	sub = _label(32, Color(1, 1, 1)); _place(sub, 0.5, 1.0, -560, -146, 560, -40); sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	tut = _label(30, Color(1, 0.95, 0.8)); _place(tut, 0.5, 0.0, -560, 70, 560, 170); tut.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help = _label(24, Color(1, 1, 1)); _place(help, 0.5, 0.5, -520, -300, 520, 300); help.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT; help.visible = false
	Fx.screen_blood.connect(_on_blood); Fx.screen_flash.connect(func(c, t): flash_c = c; flash_t = t)
	_build_pause()

func _place(c: Control, ax: float, ay: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = ax; c.anchor_right = ax; c.anchor_top = ay; c.anchor_bottom = ay
	c.offset_left = l; c.offset_top = t; c.offset_right = r; c.offset_bottom = b

const HELP = """【目標】打空對手胸前的護板（閘條），最後一條打完後處決，或走到場地另一頭轉閘輪。

【近戰】左鍵揮擊，按住左鍵蓄力重擊。右鍵格擋。
【彈反】對手打到你的前一瞬間才按右鍵：不扣體力，對手架勢大增，你得到一格扳手。
【紅光】武器發紅光的招擋不住，用空白鍵閃開。
【架勢】準星外圈越紅越危險，滿了會跪下任人宰割。對手也一樣：他晃得越厲害越接近崩架。
【處決】對手崩架（跪下）時靠近按 V，直接打掉一整條。
【卸件】扳手集滿（手腕螺帽全亮）後，在對手出招時按 F，拆掉他的零件，封住那一招。
【槍】Q 換手。左鍵開槍，右鍵瞄準，R 裝填。對手沒崩架時子彈主要打架勢，崩架時才大量扣血。
【偏斜】拿著近戰武器時，對手開槍前紅線停住的瞬間按右鍵，可以彈開子彈。
【喝水】拿近戰武器時按 R。左前臂的鋼板是你的血量。"""

func _label(size: int, col: Color) -> Label:
	var l = Label.new(); l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0)); l.add_theme_constant_override("outline_size", max(4, int(size / 5.0)))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; l.text = ""; l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l); return l

func _build_pause() -> void:
	pause_menu = Control.new(); pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT); pause_menu.visible = false; add_child(pause_menu)
	var bg = ColorRect.new(); bg.color = Color(0, 0, 0, 0.75); bg.set_anchors_preset(Control.PRESET_FULL_RECT); pause_menu.add_child(bg)
	var items = ["繼續", "操作說明", "回工棚", "離開遊戲"]
	for i in items.size():
		var l = Label.new(); l.text = items[i]; l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", 40)
		_place(l, 0.5, 0.5, -200, -130 + i * 64, 200, -70 + i * 64); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.name = "i%d" % i; pause_menu.add_child(l)
	help.text = HELP; remove_child(help); pause_menu.add_child(help)

func set_pause(on: bool) -> void:
	paused = on; pause_menu.visible = on; pause_i = 0; show_help(false)
	if not Net.active: get_tree().paused = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED

func _input(e: InputEvent) -> void:
	if not paused: return
	if help.visible:
		if e.is_action_pressed("ui_accept") or e.is_action_pressed("attack") or e.is_action_pressed("alt") or e.is_action_pressed("pause") or e.is_action_pressed("interact"):
			show_help(false); get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("ui_down") or e.is_action_pressed("mv_b"): pause_i = (pause_i + 1) % 4
	elif e.is_action_pressed("ui_up") or e.is_action_pressed("mv_f"): pause_i = (pause_i + 3) % 4
	elif e.is_action_pressed("pause"):
		set_pause(false); get_viewport().set_input_as_handled()
	elif e.is_action_pressed("ui_accept") or e.is_action_pressed("attack") or e.is_action_pressed("interact"):
		if pause_i == 1: show_help(true)
		else: pause_choice.emit([0, -1, 1, 2][pause_i])

func show_help(on: bool) -> void:
	help.visible = on
	for i in 4: pause_menu.get_node("i%d" % i).visible = not on

func _on_blood(a: float) -> void:
	var vs = root.size
	for i in int(2 + a * 6):
		var edge = randf()
		var p = Vector2(randf() * vs.x, randf() * vs.y)
		if edge < 0.7: p = Vector2(vs.x * (0.08 if randf() < 0.5 else 0.92) + randf_range(-80, 80), randf() * vs.y)
		splats.append({"p": p, "r": randf_range(20, 90) * (0.5 + a), "a": 0.85, "drip": randf_range(20, 160)})
	if splats.size() > 40: splats = splats.slice(splats.size() - 40)

# ---- 字幕 / 標題 ----
func say(who: String, text: String, dur: float) -> void:
	sub_id += 1
	var my = sub_id
	sub_name.text = who; sub.text = text
	await get_tree().create_timer(dur, true, false, true).timeout
	if my == sub_id:
		sub.text = ""; sub_name.text = ""

func title(small: String, big: String, dur: float = 2.6) -> void:
	title_small.text = small; title_big.text = big
	title_big.scale = Vector2(1.6, 1.6); title_big.pivot_offset = title_big.size * 0.5; title_big.modulate.a = 0.0; title_small.modulate.a = 0.0
	var tw = create_tween(); tw.set_parallel()
	tw.tween_property(title_big, "scale", Vector2.ONE, 0.16); tw.tween_property(title_big, "modulate:a", 1.0, 0.08); tw.tween_property(title_small, "modulate:a", 1.0, 0.3)
	tw.tween_property(title_bg, "color:a", 0.35, 0.15)
	Snd.play("boom", 2.0); Fx.add_shake(0.6)
	await get_tree().create_timer(dur, true, false, true).timeout
	var t2 = create_tween(); t2.set_parallel(); t2.tween_property(title_big, "modulate:a", 0.0, 0.5); t2.tween_property(title_small, "modulate:a", 0.0, 0.5); t2.tween_property(title_bg, "color:a", 0.0, 0.5)

func show_page(sk: Array, dur: float = 4.0) -> void:
	page = sk; page_t = dur

func prompt(act: String, wpos = null) -> void:
	prompt_act = act
	if wpos != null:
		prompt_pos = wpos; prompt_world = true
	else: prompt_world = false

func _process(d: float) -> void:
	var rd = d / max(0.01, Engine.time_scale)
	prompt_t += rd; flash_t -= rd; page_t -= rd
	for s in splats:
		s["a"] -= rd * 0.22; s["drip"] += rd * 30.0
	splats = splats.filter(func(s): return s["a"] > 0)
	if pl:
		var fr = pl.hp / max(1.0, pl.hp_max)
		omat.set_shader_parameter("red", clamp((0.45 - fr) * 2.2, 0.0, 1.0) * (0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006)))
		omat.set_shader_parameter("vig", 0.35 + 0.3 * pl.posture / max(1.0, pl.posture_max))
		var tn = 0.0
		if pl.stance == "gun" and pl.aiming and float(pl.gun.get("tunnel", 1.0)) > 1.5: tn = 1.0
		omat.set_shader_parameter("tunnel", tn)
		if pl.has_meta("bugs"):
			var b = float(pl.get_meta("bugs")) - rd; pl.set_meta("bugs", b); bugs = clamp(b * 2.0, 0.0, 1.0)
	root.queue_redraw()
	if paused:
		for i in 4:
			var l = pause_menu.get_node("i%d" % i); l.modulate = Color(1, 0.8, 0.3) if i == pause_i else Color(0.7, 0.7, 0.7)

func _draw_root() -> void:
	var vs = root.size; var c = vs * 0.5
	# 煙 / 蟲
	if smoke > 0.01: root.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.72, 0.7, 0.66, smoke * 0.7))
	if bugs > 0.01:
		var t = Time.get_ticks_msec() * 0.001
		for i in 70:
			var p = Vector2(fmod(abs(sin(i * 12.9 + t * (0.7 + i % 5 * 0.2))) * 7919.0, vs.x), fmod(abs(cos(i * 7.3 + t * (0.9 + i % 3 * 0.3))) * 6131.0, vs.y))
			root.draw_circle(p, 3.0 + (i % 4) * 1.5, Color(0.05, 0.04, 0.0, bugs * 0.9))
	# 血濺
	for s in splats:
		var col = Color(0.4, 0.0, 0.0, s["a"])
		root.draw_circle(s["p"], s["r"], col)
		root.draw_circle(s["p"] + Vector2(s["r"] * 0.6, s["r"] * 0.3), s["r"] * 0.5, col)
		root.draw_line(s["p"], s["p"] + Vector2(0, s["drip"]), col, s["r"] * 0.25)
	if flash_t > 0: root.draw_rect(Rect2(Vector2.ZERO, vs), flash_c)
	if pl and not hide_cross and pl.alive():
		# 準星：點 + 架勢環 + 體力弧
		var pr = pl.posture / max(1.0, pl.posture_max)
		var col2 = Color(1, 1, 1, 0.85).lerp(Color(1, 0.15, 0.1, 1), pr)
		root.draw_circle(c, 2.5, col2)
		if pl.stance == "gun":
			var sp = 8.0 + float(pl.gun.get("spread", 1.0)) * (3.0 if pl.aiming else 7.0) + (10.0 if pl.draw_t > 0 else 0.0)
			for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]: root.draw_line(c + dv * sp, c + dv * (sp + 7), col2, 2.0)
		if pr > 0.05: root.draw_arc(c, 26.0 - 12.0 * pr, 0, TAU, 40, col2, 2.0 + 3.0 * pr, true)
		var sf = pl.stam / max(1.0, pl.stam_max)
		if sf < 0.98:
			root.draw_arc(c, 34.0, PI * 0.5 - sf * 1.1, PI * 0.5 + sf * 1.1, 24, Color(0.6, 1.0, 0.5, 0.75) if sf > 0.25 else Color(1, 0.3, 0.2, 0.9), 3.0, true)
		if pl.state == St.BLOCK and pl.block_t < 0.2: root.draw_arc(c, 40.0, 0, TAU, 32, Color(1, 0.85, 0.3, 0.7), 2.0)
		if pl.wrench >= pl.wrench_need():
			for i in 3: root.draw_circle(c + Vector2(-14 + i * 14, 52), 4.0, Color(1, 0.75, 0.2, 0.9))
		if pl.weight > 0:
			for i in pl.weight: root.draw_rect(Rect2(c + Vector2(-26 + i * 14, 62), Vector2(10, 10)), Color(0.6, 0.6, 0.6, 0.8), true)
		if pl.tagged_t > 0: root.draw_rect(Rect2(c + Vector2(50, -40), Vector2(26, 34)), Color(0.95, 0.9, 0.7, 0.9), true)
		if not pl.mods_off.is_empty():
			root.draw_arc(c + Vector2(0, -56), 9.0, 0, TAU, 6, Color(1, 0.3, 0.2, 0.9), 3.0); root.draw_line(c + Vector2(-9, -47), c + Vector2(9, -65), Color(1, 0.3, 0.2, 0.9), 3.0)
	# 傳統血條（選項）
	if G.opt("bars") and pl:
		root.draw_rect(Rect2(40, vs.y - 60, 300, 14), Color(0, 0, 0, 0.6)); root.draw_rect(Rect2(40, vs.y - 60, 300 * pl.hp / max(1.0, pl.hp_max), 14), Color(0.75, 0.1, 0.1))
		root.draw_rect(Rect2(40, vs.y - 42, 300 * pl.stam / max(1.0, pl.stam_max), 8), Color(0.4, 0.8, 0.3))
		if foe:
			root.draw_rect(Rect2(vs.x * 0.5 - 300, 40, 600, 12), Color(0, 0, 0, 0.6)); root.draw_rect(Rect2(vs.x * 0.5 - 300, 40, 600 * foe.hp / max(1.0, foe.hp_max), 12), Color(0.75, 0.1, 0.1))
			root.draw_rect(Rect2(vs.x * 0.5 - 300, 56, 600 * foe.posture / max(1.0, foe.posture_max), 6), Color(1, 0.75, 0.2))
	# 對戰回合 / 計時
	for i in rounds.size():
		var colr = [Color(0.3, 0.3, 0.3), Color(1, 0.8, 0.3), Color(0.8, 0.15, 0.1)][rounds[i]]
		root.draw_circle(Vector2(vs.x * 0.5 - (rounds.size() - 1) * 14 + i * 28, 30), 9, colr)
	if timer_frac >= 0: root.draw_rect(Rect2(vs.x * 0.5 - 150, 48, 300 * timer_frac, 4), Color(1, 1, 1, 0.7))
	if net_warn:
		for i in 3: root.draw_rect(Rect2(vs.x - 70 + i * 14, 50 - i * 8, 9, 10 + i * 8), Color(1, 0.2, 0.1, 0.9))
	# 按鍵圖示（貼在世界裡）
	if prompt_act != "":
		var pp = c + Vector2(0, 110)
		if prompt_world and cam and is_instance_valid(cam):
			if not cam.is_position_behind(prompt_pos):
				pp = cam.unproject_position(prompt_pos); pp.x = clamp(pp.x, 60, vs.x - 60); pp.y = clamp(pp.y, 60, vs.y - 60)
		var pad = pl != null and pl.ctrl != null and pl.ctrl.get("using_pad") == true
		Icons.action(root, prompt_act, pp, pad, 1.25, font, prompt_t)
		if G.opt("text_hints"):
			var wrd = Icons.WORDS.get(prompt_act, "")
			root.draw_string_outline(font, pp + Vector2(38, 10), wrd, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 8, Color(0, 0, 0))
			root.draw_string(font, pp + Vector2(38, 10), wrd, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.9, 0.5))
	# 筆記頁
	if page_t > 0 and not page.is_empty():
		var a = clamp(page_t, 0.0, 1.0)
		var r = Rect2(vs.x - 400, vs.y - 330, 360, 280)
		root.draw_set_transform(r.position + r.size * 0.5, -0.04, Vector2.ONE)
		var rr = Rect2(-r.size * 0.5, r.size)
		root.draw_rect(rr, Color(0.82, 0.76, 0.62, a)); root.draw_rect(rr, Color(0.3, 0.25, 0.2, a), false, 3.0)
		root.draw_circle(rr.position + Vector2(60, 50), 30, Color(0.3, 0.22, 0.1, 0.25 * a))
		Icons.sketch(root, page, rr.grow(-14), font)
		root.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
