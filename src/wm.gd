extends RefCounted
# 武器模型。近戰：握把在原點，往 +Y 延伸。槍：握把在原點，槍口朝 -Z。
const M = preload("res://src/mat.gd")

static func make(id: String, st: Dictionary = {}, mods: Dictionary = {}) -> Node3D:
	var n = Node3D.new(); n.name = "W_" + id
	var S = M.steel(); var I = M.iron(); var R = M.rust(); var W = M.wood()
	var bl = 1.0
	if mods.get("barrel", "") == "short": bl = 0.6
	elif mods.get("barrel", "") == "long": bl = 1.35
	var gl = 1.15 if mods.get("grip", "") == "long" else 1.0
	match id:
		"laoban":
			M.cyl(n, 0.022, 0.55 * gl, Vector3(0, 0.2 * gl, 0), I); M.box(n, Vector3(0.13, 0.11, 0.06), Vector3(0, 0.5 * gl, 0), R)
			M.box(n, Vector3(0.05, 0.1, 0.05), Vector3(0.06, 0.58 * gl, 0), S); M.box(n, Vector3(0.05, 0.1, 0.05), Vector3(-0.06, 0.58 * gl, 0), S)
			M.cyl(n, 0.03, 0.04, Vector3(0.09, 0.5 * gl, 0), S, Vector3(0, 0, 90))
		"banshan":
			M.cyl(n, 0.025, 0.2, Vector3(0, 0.02, 0), W); M.box(n, Vector3(0.012, 0.42, 0.2), Vector3(0, 0.34, -0.06), S)
			M.box(n, Vector3(0.02, 0.42, 0.03), Vector3(0, 0.34, 0.045), I); M.cyl(n, 0.012, 0.03, Vector3(0, 0.5, -0.12), I, Vector3(0, 0, 90))
		"sanfen":
			M.cyl(n, 0.018, 2.2, Vector3(0, 0.7, 0), R); M.cyl(n, 0.03, 0.3, Vector3(0, 1.95, 0), S, Vector3.ZERO, 0.002)
			M.box(n, Vector3(0.06, 0.2, 0.06), Vector3(0, 0.0, 0), M.cloth(Color(0.3, 0.28, 0.25)))
		"gemi":
			M.cyl(n, 0.02, 1.7, Vector3(0, 0.6, 0), W)
			for i in 6: M.box(n, Vector3(0.012, 0.16, 0.07 - i * 0.008), Vector3(0, 1.45 + 0.06 * cos(i * 0.5) * i * 0.2, -0.08 - i * 0.1), S, Vector3(60 + i * 12, 0, 0))
			M.cyl(n, 0.035, 0.05, Vector3(0, 1.4, 0), I)
		"banyuan":
			M.cyl(n, 0.022, 1.0, Vector3(0, 0.35, 0), W); M.box(n, Vector3(0.24, 0.3, 0.015), Vector3(0, 1.0, 0), S); M.box(n, Vector3(0.24, 0.05, 0.03), Vector3(0, 0.86, 0), I)
			M.box(n, Vector3(0.12, 0.03, 0.03), Vector3(0, -0.15, 0), W)
		"shougong":
			M.cyl(n, 0.03, 1.3, Vector3(0, 0.5, 0), I); M.cyl(n, 0.11, 0.42, Vector3(0, 1.2, 0), M.rust(Color(0.6, 0.5, 0.12)), Vector3(90, 0, 0))
			M.cyl(n, 0.06, 0.3, Vector3(0, 1.2, -0.32), S, Vector3(90, 0, 0)); M.cyl(n, 0.05, 0.3, Vector3(0.12, 0.95, 0), M.rust(Color(0.5, 0.15, 0.1)))
			M.cyl(n, 0.012, 0.4, Vector3(0.07, 1.1, 0.1), I, Vector3(30, 0, 20))
		"knife":
			M.cyl(n, 0.018, 0.12, Vector3(0, 0, 0), W); M.box(n, Vector3(0.006, 0.26, 0.03), Vector3(0, 0.2, 0), S)
		"pipewrench":
			M.cyl(n, 0.025, 1.25, Vector3(0, 0.45, 0), M.rust(Color(0.45, 0.12, 0.1))); M.box(n, Vector3(0.06, 0.2, 0.16), Vector3(0, 1.12, -0.04), I)
			M.box(n, Vector3(0.05, 0.06, 0.12), Vector3(0, 1.24, -0.1), S); M.cyl(n, 0.035, 0.05, Vector3(0, 1.02, 0.04), S, Vector3(0, 0, 90))
		"liukong", "qikong":
			M.box(n, Vector3(0.035, 0.13, 0.05), Vector3(0, -0.05, 0.03), W, Vector3(-18, 0, 0)); M.box(n, Vector3(0.04, 0.06, 0.16), Vector3(0, 0.04, -0.05), I)
			M.cyl(n, 0.034, 0.07, Vector3(0, 0.045, -0.06), S, Vector3(90, 0, 0), -1.0, 6 if id == "liukong" else 7)
			M.cyl(n, 0.014, 0.22 * bl, Vector3(0, 0.055, -0.13 - 0.11 * bl), S, Vector3(90, 0, 0)); M.box(n, Vector3(0.012, 0.03, 0.02), Vector3(0, 0.085, 0.03), I, Vector3(30, 0, 0))
			_muz(n, Vector3(0, 0.055, -0.13 - 0.22 * bl))
		"duiban":
			M.box(n, Vector3(0.04, 0.14, 0.06), Vector3(0, -0.05, 0.05), W, Vector3(-25, 0, 0)); M.box(n, Vector3(0.07, 0.06, 0.16), Vector3(0, 0.03, -0.04), I)
			for sx in [-0.02, 0.02]: M.cyl(n, 0.02, 0.36 * bl, Vector3(sx, 0.04, -0.12 - 0.18 * bl), S, Vector3(90, 0, 0))
			_muz(n, Vector3(0, 0.04, -0.12 - 0.36 * bl))
		"guahao", "changzui":
			var L = 0.75 if id == "guahao" else 1.0
			M.box(n, Vector3(0.04, 0.1, 0.34), Vector3(0, -0.03, 0.22), W, Vector3(-8, 0, 0)); M.box(n, Vector3(0.045, 0.07, 0.24), Vector3(0, 0.03, -0.05), I)
			M.cyl(n, 0.014, L * bl, Vector3(0, 0.05, -0.17 - L * bl * 0.5), S, Vector3(90, 0, 0)); M.box(n, Vector3(0.035, 0.035, 0.3), Vector3(0, 0.0, -0.3), W)
			if id == "guahao": M.box(n, Vector3(0.012, 0.09, 0.05), Vector3(0, -0.06, 0.02), S, Vector3(30, 0, 0))
			else: M.cyl(n, 0.008, 0.08, Vector3(0.05, 0.05, 0.02), S, Vector3(0, 0, 70))
			if mods.get("sight", "") == "optic": M.cyl(n, 0.02, 0.2, Vector3(0, 0.1, -0.05), I, Vector3(90, 0, 0))
			_muz(n, Vector3(0, 0.05, -0.17 - L * bl))
		"menlei":
			M.box(n, Vector3(0.04, 0.1, 0.28), Vector3(0, -0.03, 0.2), W, Vector3(-8, 0, 0)); M.cyl(n, 0.06, 0.2, Vector3(0, 0.04, -0.05), R, Vector3(90, 0, 0))
			M.cyl(n, 0.045, 0.4 * bl, Vector3(0, 0.04, -0.15 - 0.2 * bl), I, Vector3(90, 0, 0)); _muz(n, Vector3(0, 0.04, -0.15 - 0.4 * bl))
		"dianming":
			M.box(n, Vector3(0.04, 0.13, 0.05), Vector3(0, -0.05, 0.03), I, Vector3(-15, 0, 0)); M.box(n, Vector3(0.06, 0.09, 0.3), Vector3(0, 0.04, -0.1), M.rust(Color(0.6, 0.5, 0.12)))
			M.cyl(n, 0.045, 0.22, Vector3(0, -0.04, -0.12), M.rust(Color(0.5, 0.15, 0.1)), Vector3(90, 0, 0)); M.cyl(n, 0.012, 0.25 * bl, Vector3(0, 0.05, -0.25 - 0.12 * bl), S, Vector3(90, 0, 0))
			M.cyl(n, 0.02, 0.01, Vector3(0.035, 0.06, 0.0), M.glow(Color(0.9, 0.9, 0.7), 0.5), Vector3(0, 0, 90)); _muz(n, Vector3(0, 0.05, -0.25 - 0.25 * bl))
		"huizhi":
			M.box(n, Vector3(0.04, 0.05, 0.4), Vector3(0, 0, -0.1), W); M.box(n, Vector3(0.5, 0.02, 0.03), Vector3(0, 0.02, -0.28), S); M.cyl(n, 0.04, 0.05, Vector3(0, -0.04, 0.02), I, Vector3(0, 0, 90))
			_muz(n, Vector3(0, 0.02, -0.32))
		"shuiba":
			M.cyl(n, 0.07, 0.16, Vector3.ZERO, R); M.cyl(n, 0.02, 0.1, Vector3(0, 0.1, 0.05), I, Vector3(40, 0, 0)); M.box(n, Vector3(0.1, 0.02, 0.02), Vector3(0, 0.12, 0), I)
		"jiadang":
			M.box(n, Vector3(0.2, 0.2, 0.3), Vector3(0, 0.02, -0.1), M.wood(Color(0.55, 0.45, 0.25))); M.cyl(n, 0.06, 0.2, Vector3(0, 0.02, -0.32), I, Vector3(90, 0, 0)); _muz(n, Vector3(0, 0.02, -0.42))
		"laihui":
			M.box(n, Vector3(0.05, 0.06, 0.35), Vector3(0, 0, -0.08), I); M.cyl(n, 0.13, 0.008, Vector3(0, 0.04, -0.2), S, Vector3.ZERO, -1.0, 10); _muz(n, Vector3(0, 0.04, -0.3))
		"jieyixia":
			M.box(n, Vector3(0.1, 0.04, 0.13), Vector3.ZERO, M.cloth(Color(0.25, 0.2, 0.15))); M.cyl(n, 0.05, 0.03, Vector3(0, 0.03, 0), M.rust(Color(0.7, 0.35, 0.15)))
			M.cyl(n, 0.02, 0.04, Vector3(0, 0.04, 0), M.glow(Color(0.3, 0.6, 1.0), 1.5))
		"guodian":
			M.cyl(n, 0.02, 0.6, Vector3(0, 0.2, 0), W)
			for sx in [-0.04, 0.04]: M.cyl(n, 0.008, 0.22, Vector3(sx, 0.6, 0), S)
			M.box(n, Vector3(0.1, 0.12, 0.08), Vector3(0, 0.1, 0.06), I); M.box(n, Vector3(0.02, 0.02, 0.02), Vector3(0, 0.7, 0), M.glow(Color(0.5, 0.8, 1.0), 2.0))
		_:
			M.cyl(n, 0.02, 0.6, Vector3(0, 0.2, 0), I)
	return n

static func _muz(n: Node3D, p: Vector3) -> void:
	var m = Marker3D.new(); m.name = "muzzle"; n.add_child(m); m.position = p

static func muzzle(w: Node3D) -> Vector3:
	var m = w.get_node_or_null("muzzle")
	return m.global_position if m else w.global_position

# 讓武器發紅光（不可擋招的預警）
static func warn(w: Node3D, on: bool) -> void:
	if w == null: return
	var l = w.get_node_or_null("warn")
	if on and l == null:
		l = OmniLight3D.new(); l.name = "warn"; l.light_color = Color(1, 0.1, 0.05); l.light_energy = 4.0; l.omni_range = 3.0; w.add_child(l); l.position = Vector3(0, 0.5, 0)
		var s = MeshInstance3D.new(); s.name = "warnm"; var sm = SphereMesh.new(); sm.radius = 0.12; sm.height = 0.24; s.mesh = sm
		s.material_override = M.glow(Color(1, 0.1, 0.05), 6.0); l.add_child(s)
	elif not on and l != null: l.queue_free()
