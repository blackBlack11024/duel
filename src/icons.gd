extends RefCounted
# 圖示：按鍵、數值、筆記本草圖。全部用 CanvasItem 的繪圖指令畫。
const KEYS = {"attack": ["mouse", 0], "alt": ["mouse", 1], "dodge": ["wide", "空白"], "interact": ["key", "V"], "core": ["key", "F"], "core2": ["key", "G"],
	"switch": ["key", "Q"], "reload": ["key", "R"], "drink": ["key", "R"], "gadget": ["key", "E"], "jump": ["wide", "Ctrl"], "mv": ["key", "WASD"], "hold": ["mouse", 0]}
const PADS = {"attack": "RT", "alt": "LT", "dodge": "B", "interact": "RS", "core": "LB", "core2": "↓", "switch": "Y", "reload": "X", "drink": "↑", "gadget": "RB", "jump": "A", "mv": "LS", "hold": "RT"}
const WORDS = {"attack": "攻擊", "alt": "格擋", "dodge": "閃避", "interact": "處決", "core": "卸件", "switch": "換手", "reload": "裝填", "drink": "喝水", "gadget": "奇械", "hold": "按住", "core2": "核心"}

static func action(ci: CanvasItem, act: String, pos: Vector2, pad: bool, sc: float = 1.0, font: Font = null, pulse: float = 0.0) -> void:
	var col = Color(1, 1, 1, 0.95)
	var bg = Color(0.05, 0.05, 0.05, 0.75)
	var r = 22.0 * sc * (1.0 + 0.08 * sin(pulse * 8.0))
	if pad:
		ci.draw_circle(pos, r, bg); ci.draw_arc(pos, r, 0, TAU, 32, col, 2.5 * sc, true)
		if font: _txt(ci, font, PADS.get(act, "?"), pos, int(18 * sc), col)
		return
	var k = KEYS.get(act, ["key", "?"])
	match k[0]:
		"mouse":
			var w = 26.0 * sc; var h = 40.0 * sc
			var rect = Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h))
			ci.draw_rect(rect, bg, true); ci.draw_rect(rect, col, false, 2.5 * sc)
			var half = Rect2(rect.position + Vector2(0 if k[1] == 0 else w * 0.5, 0), Vector2(w * 0.5, h * 0.45))
			ci.draw_rect(half, Color(1, 0.75, 0.2), true)
			ci.draw_line(rect.position + Vector2(w * 0.5, 0), rect.position + Vector2(w * 0.5, h * 0.45), col, 2.0 * sc)
			ci.draw_line(rect.position + Vector2(0, h * 0.45), rect.position + Vector2(w, h * 0.45), col, 2.0 * sc)
			if act == "hold":
				for i in 3: ci.draw_line(pos + Vector2(-12 + i * 12, h * 0.75) * 1.0, pos + Vector2(-6 + i * 12, h * 0.75), col, 3.0 * sc)
		"wide":
			var rect2 = Rect2(pos - Vector2(46, 18) * sc, Vector2(92, 36) * sc)
			ci.draw_rect(rect2, bg, true); ci.draw_rect(rect2, col, false, 2.5 * sc)
			if font: _txt(ci, font, k[1], pos, int(16 * sc), col)
		_:
			var s = 36.0 * sc
			var rect3 = Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s))
			ci.draw_rect(rect3, bg, true); ci.draw_rect(rect3, col, false, 2.5 * sc)
			if font: _txt(ci, font, k[1], pos, int(20 * sc) if str(k[1]).length() < 2 else int(11 * sc), col)

static func _txt(ci: CanvasItem, font: Font, s: String, pos: Vector2, size: int, col: Color) -> void:
	var w = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	ci.draw_string(font, pos + Vector2(-w.x * 0.5, size * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# 數值圖示
static func stat(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color) -> void:
	match name:
		"dmg":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.6, s * 0.4), c + Vector2(0, s), c + Vector2(-s * 0.6, s * 0.4)]), col)
		"post":
			ci.draw_arc(c, s * 0.9, 0, TAU, 24, col, 3.0); ci.draw_line(c + Vector2(-s, s) * 0.6, c + Vector2(s, -s) * 0.6, col, 3.0)
		"range":
			ci.draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), col, 3.0)
			ci.draw_line(c + Vector2(s, 0), c + Vector2(s * 0.4, -s * 0.5), col, 3.0); ci.draw_line(c + Vector2(s, 0), c + Vector2(s * 0.4, s * 0.5), col, 3.0)
		"spread":
			ci.draw_arc(c, s * 0.9, 0, TAU, 24, col, 2.5); ci.draw_circle(c, s * 0.25, col)
		"recoil":
			ci.draw_line(c + Vector2(-s, s * 0.6), c + Vector2(0, -s * 0.6), col, 3.0); ci.draw_line(c + Vector2(0, -s * 0.6), c + Vector2(s, s * 0.6), col, 3.0)
		"draw":
			ci.draw_arc(c, s * 0.9, 0, TAU, 24, col, 2.5); ci.draw_line(c, c + Vector2(0, -s * 0.7), col, 2.5); ci.draw_line(c, c + Vector2(s * 0.5, 0), col, 2.5)
		"reload":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.8), Vector2(s * 0.7, s * 1.6)), col, false, 2.5); ci.draw_circle(c + Vector2(0, -s * 0.8), s * 0.35, col)
		"rof":
			for i in 3: ci.draw_circle(c + Vector2(-s * 0.7 + i * s * 0.7, 0), s * 0.22, col)
		"mag":
			for i in 3: ci.draw_rect(Rect2(c + Vector2(-s * 0.8 + i * s * 0.6, -s * 0.7), Vector2(s * 0.35, s * 1.4)), col, true)
		"rel":
			ci.draw_arc(c, s * 0.8, 0, TAU, 8, col, 3.0); ci.draw_circle(c, s * 0.25, col)
		"stab":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.8), c + Vector2(s * 0.8, -s * 0.8), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0)]), col)
		"parry":
			for i in 8:
				var a = i * TAU / 8.0; ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.35, c + Vector2(cos(a), sin(a)) * s, col, 2.5)
		"heavy":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.8, -s * 0.9), Vector2(s * 1.6, s * 0.8)), col, true); ci.draw_line(c + Vector2(0, -s * 0.1), c + Vector2(0, s), col, 4.0)
		"dur":
			ci.draw_line(c + Vector2(-s, s * 0.5), c + Vector2(s, s * 0.5), col, 4.0)
			for i in 4: ci.draw_line(c + Vector2(-s * 0.8 + i * s * 0.5, s * 0.5), c + Vector2(-s * 0.6 + i * s * 0.5, -s * 0.5), col, 2.0)
		"scrap":
			ci.draw_arc(c, s * 0.8, 0, TAU, 6, col, 4.0); ci.draw_circle(c, s * 0.2, col)
		"fine":
			for i in 8:
				var a2 = i * TAU / 8.0; ci.draw_line(c, c + Vector2(cos(a2), sin(a2)) * s, col, 3.0)
			ci.draw_circle(c, s * 0.5, col); ci.draw_circle(c, s * 0.2, Color(0, 0, 0, 0.8))
		"ticket":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.65, s * 0.25), c + Vector2(0, s), c + Vector2(-s * 0.65, s * 0.25)]), col)
			ci.draw_circle(c + Vector2(0, s * 0.35), s * 0.62, col)
		"lock":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.1), Vector2(s * 1.4, s * 1.1)), col, true); ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.5, PI, TAU, 12, col, 3.0)
		_:
			ci.draw_circle(c, s * 0.5, col)

# 筆記本草圖
static func sketch(ci: CanvasItem, sk: Array, rect: Rect2, font: Font) -> void:
	var ink = Color(0.12, 0.1, 0.08, 0.9); var red = Color(0.6, 0.1, 0.05, 0.9)
	for cmd in sk:
		match cmd[0]:
			"man": _man(ci, rect.position + Vector2(cmd[1], cmd[2]) * rect.size, rect.size.y * 0.22, cmd[3], ink)
			"x":
				var p = rect.position + Vector2(cmd[1], cmd[2]) * rect.size; var s = rect.size.y * 0.07
				ci.draw_line(p + Vector2(-s, -s), p + Vector2(s, s), red, 5.0); ci.draw_line(p + Vector2(-s, s), p + Vector2(s, -s), red, 5.0)
			"o":
				ci.draw_arc(rect.position + Vector2(cmd[1], cmd[2]) * rect.size, rect.size.y * 0.13, 0.3, TAU + 0.6, 28, red, 4.0)
			"arrow":
				var a = rect.position + Vector2(cmd[1], cmd[2]) * rect.size; var b = rect.position + Vector2(cmd[3], cmd[4]) * rect.size
				ci.draw_line(a, b, ink, 4.0); var dir = (b - a).normalized(); var n = Vector2(-dir.y, dir.x)
				ci.draw_line(b, b - dir * 16 + n * 9, ink, 4.0); ci.draw_line(b, b - dir * 16 - n * 9, ink, 4.0)
			"word":
				if font: ci.draw_string(font, rect.position + Vector2(cmd[1], cmd[2]) * rect.size, cmd[3], HORIZONTAL_ALIGNMENT_LEFT, -1, int(rect.size.y * 0.1), ink)
			"obj":
				var p2 = rect.position + Vector2(cmd[2], cmd[3]) * rect.size; var s2 = rect.size.y * 0.06
				match cmd[1]:
					"part":
						ci.draw_arc(p2, s2 * 0.6, 0, TAU, 6, ink, 4.0)
					"hive":
						ci.draw_rect(Rect2(p2 - Vector2(s2, s2) * 1.2, Vector2(s2, s2) * 2.4), ink, false, 4.0)
						for i in 5: ci.draw_circle(p2 + Vector2(cos(i * 1.3), sin(i * 2.1)) * s2 * 2.2, 3.0, ink)
					"bomb":
						ci.draw_circle(p2, s2, ink); ci.draw_line(p2 + Vector2(0, -s2), p2 + Vector2(s2 * 0.6, -s2 * 1.8), ink, 3.0)
					"wall":
						ci.draw_rect(Rect2(p2 - Vector2(s2 * 0.4, s2 * 3.5), Vector2(s2 * 0.8, s2 * 5.0)), ink, true)

static func _man(ci: CanvasItem, p: Vector2, h: float, pose: String, ink: Color) -> void:
	var w = 4.0
	var head = p + Vector2(0, -h * 1.0); var neck = p + Vector2(0, -h * 0.75); var hip = p + Vector2(0, 0)
	var la = neck + Vector2(-h * 0.35, h * 0.4); var ra = neck + Vector2(h * 0.35, h * 0.4)
	var ll = hip + Vector2(-h * 0.25, h * 0.8); var rl = hip + Vector2(h * 0.25, h * 0.8)
	match pose:
		"raise":
			ra = neck + Vector2(h * 0.2, -h * 0.7); la = neck + Vector2(-h * 0.1, -h * 0.65)
			ci.draw_line(ra, ra + Vector2(h * 0.1, -h * 0.6), ink, w + 1)
		"shoot":
			ra = neck + Vector2(h * 0.6, 0.0); ci.draw_line(ra, ra + Vector2(h * 0.3, 0), ink, w + 2)
		"reach": la = neck + Vector2(-h * 0.65, -h * 0.05)
		"swing":
			la = neck + Vector2(-h * 0.5, -h * 0.3); ci.draw_line(la, la + Vector2(-h * 0.5, -h * 0.4), ink, w + 1)
		"slide":
			hip = p + Vector2(h * 0.15, h * 0.2); ll = hip + Vector2(-h * 0.6, h * 0.5); rl = hip + Vector2(h * 0.4, h * 0.6)
		"kneel":
			hip = p + Vector2(0, h * 0.3); ll = hip + Vector2(-h * 0.4, h * 0.4); rl = hip + Vector2(h * 0.3, h * 0.45); head += Vector2(-h * 0.1, h * 0.3); neck += Vector2(-h * 0.05, h * 0.3)
		"hang":
			ll = hip + Vector2(-h * 0.1, -h * 0.9) + Vector2(0, h * 1.6); ra = neck + Vector2(h * 0.4, -h * 0.5)
		"card":
			la = neck + Vector2(-h * 0.45, -h * 0.2); ci.draw_rect(Rect2(la + Vector2(-h * 0.3, -h * 0.5), Vector2(h * 0.5, h * 0.4)), ink, false, 3.0)
	ci.draw_arc(head, h * 0.2, 0, TAU, 16, ink, w)
	ci.draw_line(neck, hip, ink, w); ci.draw_line(neck, la, ink, w); ci.draw_line(neck, ra, ink, w); ci.draw_line(hip, ll, ink, w); ci.draw_line(hip, rl, ink, w)
