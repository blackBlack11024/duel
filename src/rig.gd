extends Node3D
# 程序化人形。關節為 Node3D，姿勢為歐拉角（度）。面向 -Z。
const M = preload("res://src/mat.gd")
var J = {}
var cur = {}
var p = {}
var s = 1.0
var action = null   # {wu:pose, hit:pose, t, twu, tact, trec}
var hold = ""        # 持續姿勢名稱
var hold_w = 0.0
var walk = 0.0
var move_speed = 0.0
var wobble = 0.0     # 架勢晃動 0..1
var plates = []      # [bar][seg] MeshInstance3D
var base_y = 0.0
var dead = false
var flinch_t = 0.0
var flinch_dir = Vector3.ZERO
var breath = 0.0
var severed = {}

const POSES = {
	"idle": {"sh_r": [12, 0, 10], "el_r": [38, 0, 0], "sh_l": [6, 0, -10], "el_l": [28, 0, 0], "spine": [6, 0, 0], "hip_r": [6, 0, 4], "kn_r": [-12, 0, 0], "hip_l": [6, 0, -4], "kn_l": [-12, 0, 0]},
	"guard": {"sh_r": [62, 0, -28], "el_r": [85, 0, 0], "sh_l": [52, 0, 25], "el_l": [75, 0, 0], "spine": [10, 0, 0], "wr_r": [0, 0, 60], "hip_r": [14, 0, 4], "kn_r": [-28, 0, 0], "hip_l": [14, 0, -4], "kn_l": [-28, 0, 0], "root_y": -0.06},
	"swing_r": {"wu": {"chest": [0, -55, 0], "spine": [0, -20, 0], "sh_r": [50, 0, 95], "el_r": [70, 0, 0], "sh_l": [40, 0, -5], "el_l": [60, 0, 0], "wr_r": [-30, 0, 0]},
		"hit": {"chest": [0, 55, 0], "spine": [12, 25, 0], "sh_r": [75, 0, -35], "el_r": [8, 0, 0], "sh_l": [0, 0, -30], "el_l": [40, 0, 0], "wr_r": [40, 0, 0]}},
	"swing_l": {"wu": {"chest": [0, 50, 0], "spine": [0, 20, 0], "sh_r": [85, 0, -70], "el_r": [80, 0, 0], "sh_l": [10, 0, -30], "el_l": [40, 0, 0], "wr_r": [-20, 0, 0]},
		"hit": {"chest": [0, -50, 0], "spine": [10, -20, 0], "sh_r": [65, 0, 75], "el_r": [6, 0, 0], "sh_l": [30, 0, -5], "el_l": [60, 0, 0], "wr_r": [40, 0, 0]}},
	"overhead": {"wu": {"spine": [-18, 0, 0], "sh_r": [175, 0, 12], "el_r": [45, 0, 0], "sh_l": [165, 0, -12], "el_l": [50, 0, 0], "head": [-10, 0, 0], "root_y": 0.05, "wr_r": [-50, 0, 0]},
		"hit": {"spine": [38, 0, 0], "sh_r": [42, 0, 0], "el_r": [4, 0, 0], "sh_l": [42, 0, 0], "el_l": [10, 0, 0], "root_y": -0.12, "hip_r": [30, 0, 0], "kn_r": [-45, 0, 0], "hip_l": [30, 0, 0], "kn_l": [-45, 0, 0], "wr_r": [50, 0, 0]}},
	"slam": {"wu": {"spine": [-22, 0, 0], "sh_r": [178, 0, 5], "el_r": [20, 0, 0], "sh_l": [178, 0, -5], "el_l": [20, 0, 0], "root_y": 0.12, "wr_r": [-40, 0, 0]},
		"hit": {"spine": [50, 0, 0], "sh_r": [35, 0, 0], "el_r": [2, 0, 0], "sh_l": [35, 0, 0], "el_l": [2, 0, 0], "root_y": -0.3, "hip_r": [55, 0, 8], "kn_r": [-80, 0, 0], "hip_l": [55, 0, -8], "kn_l": [-80, 0, 0], "wr_r": [60, 0, 0]}},
	"thrust": {"wu": {"chest": [0, -35, 0], "sh_r": [-35, 0, 15], "el_r": [105, 0, 0], "sh_l": [60, 0, -10], "el_l": [30, 0, 0], "spine": [-5, 0, 0], "wr_r": [80, 0, 0]},
		"hit": {"chest": [0, 28, 0], "sh_r": [88, 0, -5], "el_r": [0, 0, 0], "sh_l": [-20, 0, -20], "el_l": [50, 0, 0], "spine": [18, 0, 0], "hip_r": [-20, 0, 0], "hip_l": [40, 0, 0], "kn_l": [-40, 0, 0], "wr_r": [85, 0, 0]}},
	"sweep": {"wu": {"spine": [22, -20, 0], "chest": [0, -60, 0], "sh_r": [25, 0, 70], "el_r": [35, 0, 0], "root_y": -0.15, "hip_r": [35, 0, 0], "kn_r": [-50, 0, 0], "hip_l": [35, 0, 0], "kn_l": [-50, 0, 0]},
		"hit": {"spine": [30, 20, 0], "chest": [0, 60, 0], "sh_r": [40, 0, -40], "el_r": [5, 0, 0], "root_y": -0.15, "hip_r": [35, 0, 0], "kn_r": [-50, 0, 0], "hip_l": [35, 0, 0], "kn_l": [-50, 0, 0], "wr_r": [60, 0, 0]}},
	"shoot": {"wu": {"sh_l": [86, 0, 4], "el_l": [4, 0, 0], "chest": [0, 12, 0], "sh_r": [10, 0, 14], "el_r": [30, 0, 0], "head": [0, -8, 0]},
		"hit": {"sh_l": [112, 0, 4], "el_l": [22, 0, 0], "chest": [-6, 12, 0], "sh_r": [10, 0, 14], "el_r": [30, 0, 0]}},
	"shoot2": {"wu": {"sh_l": [84, 0, 14], "el_l": [8, 0, 0], "sh_r": [70, 0, -42], "el_r": [70, 0, 0], "chest": [0, 20, 0], "head": [0, -15, 8]},
		"hit": {"sh_l": [98, 0, 14], "el_l": [20, 0, 0], "sh_r": [78, 0, -42], "el_r": [80, 0, 0], "chest": [-8, 20, 0], "head": [-5, -15, 8]}},
	"throw": {"wu": {"sh_l": [-45, 0, -25], "el_l": [95, 0, 0], "chest": [0, 35, 0], "spine": [-8, 0, 0]},
		"hit": {"sh_l": [105, 0, 0], "el_l": [0, 0, 0], "chest": [0, -30, 0], "spine": [15, 0, 0]}},
	"kick": {"wu": {"hip_r": [45, 0, 0], "kn_r": [-95, 0, 0], "spine": [-8, 0, 0], "sh_r": [20, 0, 30], "sh_l": [20, 0, -30]},
		"hit": {"hip_r": [88, 0, 0], "kn_r": [-4, 0, 0], "spine": [-16, 0, 0], "sh_r": [-20, 0, 30], "sh_l": [-20, 0, -30]}},
	"grab": {"wu": {"sh_l": [35, 0, -45], "el_l": [70, 0, 0], "chest": [0, 30, 0]},
		"hit": {"sh_l": [88, 0, 12], "el_l": [8, 0, 0], "chest": [0, -25, 0], "spine": [22, 0, 0]}},
	"card": {"sh_l": [72, 0, -12], "el_l": [112, 0, 0], "head": [8, 0, 0]},
	"reload": {"sh_l": [48, 0, 12], "el_l": [92, 0, 0], "sh_r": [42, 0, -28], "el_r": [100, 0, 0], "head": [28, 0, 0], "spine": [12, 0, 0]},
	"broken": {"root_y": -0.5, "hip_r": [85, 0, 6], "kn_r": [-105, 0, 0], "hip_l": [8, 0, -6], "kn_l": [-98, 0, 0], "spine": [38, 0, 0], "head": [32, 0, 0], "sh_r": [14, 0, 14], "el_r": [18, 0, 0], "sh_l": [14, 0, -14], "el_l": [18, 0, 0]},
	"stagger": {"spine": [-22, 10, 0], "head": [-18, 0, 0], "sh_r": [-25, 0, 50], "el_r": [30, 0, 0], "sh_l": [-25, 0, -50], "el_l": [30, 0, 0], "hip_r": [-10, 0, 0], "kn_r": [-20, 0, 0]},
	"dead": {"root_x": -88, "root_y": -0.82, "sh_r": [0, 0, 70], "sh_l": [0, 0, -60], "hip_r": [0, 0, 12], "hip_l": [0, 0, -18], "head": [0, 40, 0]},
	"sit": {"root_y": -0.48, "hip_r": [92, 0, 8], "kn_r": [-92, 0, 0], "hip_l": [92, 0, -8], "kn_l": [-92, 0, 0], "spine": [16, 0, 0], "sh_r": [28, 0, 6], "el_r": [50, 0, 0], "sh_l": [28, 0, -6], "el_l": [50, 0, 0], "head": [14, 0, 0]},
	"offer": {"sh_l": [72, 0, 6], "el_l": [22, 0, 0], "root_y": -0.48, "hip_r": [92, 0, 8], "kn_r": [-92, 0, 0], "hip_l": [92, 0, -8], "kn_l": [-92, 0, 0], "spine": [20, 0, 0]},
	"lift": {"sh_r": [95, 0, -8], "el_r": [30, 0, 0], "spine": [-6, 0, 0], "head": [-12, 0, 0]},
	"hang": {"root_x": 178, "root_y": 1.6, "sh_r": [170, 0, 20], "sh_l": [170, 0, -20], "el_l": [30, 0, 0]},
	"watch": {"sh_l": [55, 0, 20], "el_l": [110, 0, 0], "head": [28, 14, 0]},
	"feed": {"spine": [30, 0, 0], "sh_r": [50, 0, 0], "el_r": [40, 0, 0], "head": [20, 0, 0]},
	"nod": {"head": [28, 0, 0]}, "point": {"sh_r": [60, 0, 0], "el_r": [5, 0, 0], "head": [20, 0, 0]},
	"shrug": {"sh_r": [20, 0, 50], "el_r": [100, 0, 0], "sh_l": [20, 0, -50], "el_l": [100, 0, 0], "head": [0, 0, 12]},
	"tap": {"sh_r": [75, 0, -30], "el_r": [70, 0, 0], "sh_l": [70, 0, 30], "el_l": [70, 0, 0]},
	"aim": {"sh_r": [86, 0, -6], "el_r": [6, 0, 0], "sh_l": [70, 0, 30], "el_l": [60, 0, 0], "chest": [0, -10, 0]},
}

func build(params: Dictionary) -> void:
	p = params; s = float(p.get("h", 1.8)) / 1.8
	var b = float(p.get("bulk", 1.0))
	var SK = M.skin(p.get("skin", Color(0.7, 0.55, 0.45))); var CL = M.cloth(p.get("cloth", Color(0.3, 0.3, 0.3)))
	var DK = M.cloth(p.get("cloth", Color(0.3, 0.3, 0.3)).darkened(0.45)); var LE = M.cloth(Color(0.18, 0.13, 0.1))
	var root = _j("root", self, Vector3(0, 0.95 * s, 0)); base_y = 0.95 * s
	M.box(root, Vector3(0.36 * b, 0.2, 0.24 * b) * s, Vector3(0, 0.02, 0) * s, DK)
	var spine = _j("spine", root, Vector3(0, 0.1, 0) * s)
	M.box(spine, Vector3(0.36 * b, 0.26, 0.25 * b) * s, Vector3(0, 0.12, 0) * s, CL)
	if b > 1.2: M.ball(spine, 0.2 * s * b, Vector3(0, 0.08, -0.1) * s, CL, Vector3(1.0, 0.9, 0.9))
	var chest = _j("chest", spine, Vector3(0, 0.25, 0) * s)
	M.box(chest, Vector3(0.48 * b, 0.32, 0.28 * b) * s, Vector3(0, 0.15, 0) * s, CL)
	M.box(chest, Vector3(0.56 * b, 0.1, 0.24 * b) * s, Vector3(0, 0.28, 0) * s, CL)
	var head = _j("head", chest, Vector3(0, 0.36, 0) * s)
	M.cyl(head, 0.06 * s * b, 0.1 * s, Vector3(0, 0.0, 0), SK)
	var hs = 1.0 / sqrt(b) if b > 1.2 else 1.0
	M.ball(head, 0.125 * s * hs, Vector3(0, 0.16, 0) * s, SK, Vector3(0.92, 1.1, 1.0))
	M.box(head, Vector3(0.17, 0.09, 0.15) * s * hs * (1.0 + (b - 1.0) * 0.6), Vector3(0, 0.07, -0.03) * s, SK)
	M.box(head, Vector3(0.035, 0.06, 0.05) * s, Vector3(0, 0.15, -0.125 * hs) * s, SK, Vector3(-15, 0, 0))
	M.box(head, Vector3(0.15, 0.03, 0.03) * s * hs, Vector3(0, 0.2, -0.1 * hs) * s, M.cloth(Color(0.05, 0.04, 0.04)))
	M.box(head, Vector3(0.08, 0.012, 0.02) * s, Vector3(0, 0.085, -0.115 * hs) * s, M.cloth(Color(0.2, 0.08, 0.07)))
	for side in [1, -1]:
		var n = "r" if side == 1 else "l"
		var sh = _j("sh_" + n, chest, Vector3(0.29 * b * side, 0.27, 0) * s)
		M.ball(sh, 0.085 * s * b, Vector3.ZERO, CL)
		M.cap(sh, 0.065 * s * b, 0.34 * s, Vector3(0, -0.16, 0) * s, CL)
		var el = _j("el_" + n, sh, Vector3(0, -0.32, 0) * s)
		M.cap(el, 0.058 * s * b, 0.32 * s, Vector3(0, -0.14, 0) * s, SK)
		M.cyl(el, 0.066 * s * b, 0.1 * s, Vector3(0, -0.22, 0) * s, LE)
		var wr = _j("wr_" + n, el, Vector3(0, -0.3, 0) * s)
		M.box(wr, Vector3(0.1, 0.12, 0.07) * s * b, Vector3(0, -0.05, 0) * s, SK)
		var hand = Node3D.new(); hand.name = "hand"; wr.add_child(hand); hand.position = Vector3(0, -0.06, -0.02) * s
		J["hand_" + n] = hand
		var hip = _j("hip_" + n, root, Vector3(0.11 * b * side, -0.06, 0) * s)
		M.cap(hip, 0.085 * s * b, 0.46 * s, Vector3(0, -0.22, 0) * s, DK)
		var kn = _j("kn_" + n, hip, Vector3(0, -0.44, 0) * s)
		M.cap(kn, 0.07 * s * b, 0.44 * s, Vector3(0, -0.2, 0) * s, DK)
		M.box(kn, Vector3(0.11, 0.09, 0.27) * s * b, Vector3(0, -0.43, -0.06) * s, LE)
	_acc(str(p.get("acc", "")), chest, spine, head, root)
	_plates(chest, int(p.get("bars", 0)), b)
	for k in J: cur[k] = Vector3.ZERO
	cur["root_y"] = 0.0; cur["root_x"] = 0.0

func _j(n: String, parent: Node, pos: Vector3) -> Node3D:
	var j = Node3D.new(); j.name = n; parent.add_child(j); j.position = pos; J[n] = j; return j

func _acc(a: String, chest: Node3D, spine: Node3D, head: Node3D, root: Node3D) -> void:
	var b = float(p.get("bulk", 1.0))
	match a:
		"apron":
			M.box(spine, Vector3(0.4 * b, 0.75, 0.02) * s, Vector3(0, -0.05, -0.15 * b) * s, M.cloth(Color(0.75, 0.7, 0.62)))
			M.box(spine, Vector3(0.22 * b, 0.3, 0.022) * s, Vector3(0.04, -0.1, -0.152 * b) * s, M.blood())
			M.box(chest, Vector3(0.3 * b, 0.25, 0.02) * s, Vector3(0, 0.12, -0.15 * b) * s, M.cloth(Color(0.75, 0.7, 0.62)))
		"bag":
			M.box(spine, Vector3(0.12, 0.3, 0.34) * s, Vector3(-0.24, 0.0, 0) * s, M.cloth(Color(0.5, 0.38, 0.2)))
			M.box(chest, Vector3(0.05, 0.5, 0.3) * s, Vector3(0, 0.1, 0) * s, M.cloth(Color(0.5, 0.38, 0.2)), Vector3(0, 0, 35))
			M.cyl(head, 0.15 * s, 0.03 * s, Vector3(0, 0.26, -0.03) * s, M.cloth(Color(0.2, 0.25, 0.35))); M.box(head, Vector3(0.2, 0.01, 0.12) * s, Vector3(0, 0.25, -0.16) * s, M.cloth(Color(0.2, 0.25, 0.35)))
		"hat":
			M.cyl(head, 0.34 * s, 0.14 * s, Vector3(0, 0.3, 0) * s, M.wood(Color(0.7, 0.6, 0.35)), Vector3.ZERO, 0.02)
			M.cyl(head, 0.3 * s, 0.3 * s, Vector3(0, 0.1, 0) * s, M.ghost(Color(0.1, 0.1, 0.1, 0.35)))
			M.box(chest, Vector3(0.24, 0.3, 0.22) * s, Vector3(0, 0.1, 0.24) * s, M.wood(Color(0.55, 0.45, 0.25)))
		"pack":
			M.box(chest, Vector3(0.44, 0.55, 0.3) * s, Vector3(0, 0.05, 0.28) * s, M.cloth(Color(0.3, 0.33, 0.22)))
			for i in 4: M.ball(chest, 0.06 * s, Vector3(-0.15 + i * 0.1, 0.36, 0.3) * s, M.iron())
			M.box(head, Vector3(0.2, 0.08, 0.2) * s, Vector3(0, 0.2, 0) * s, M.cloth(Color(0.25, 0.2, 0.15)))
			for sx in [-1, 1]: M.cyl(head, 0.055 * s, 0.05 * s, Vector3(0.12 * sx, 0.15, 0) * s, M.iron(), Vector3(0, 0, 90))
		"exo":
			var Y = M.rust(Color(0.75, 0.6, 0.1))
			M.box(chest, Vector3(0.7, 0.06, 0.06) * s, Vector3(0, 0.3, 0.12) * s, Y); M.box(spine, Vector3(0.08, 0.7, 0.08) * s, Vector3(0, 0.2, 0.2) * s, Y)
			M.cyl(chest, 0.1 * s, 0.4 * s, Vector3(0.14, 0.1, 0.28) * s, M.rust(Color(0.5, 0.15, 0.1))).name = "tank"
			M.box(chest, Vector3(0.14, 0.18, 0.08) * s, Vector3(-0.16, 0.1, 0.24) * s, M.iron()).name = "ctrlbox"
			for n in ["sh_r", "sh_l", "hip_r", "hip_l", "kn_r", "kn_l", "el_r", "el_l"]:
				var side = 1 if n.ends_with("r") else -1
				M.box(J[n], Vector3(0.035, 0.3, 0.035) * s, Vector3(0.1 * side, -0.16, 0) * s, Y); M.cyl(J[n], 0.045 * s, 0.05 * s, Vector3(0.1 * side, 0, 0) * s, M.iron(), Vector3(0, 0, 90))
			M.box(head, Vector3(0.24, 0.07, 0.24) * s, Vector3(0, 0.26, 0) * s, Y); M.box(head, Vector3(0.16, 0.04, 0.02) * s, Vector3(0, 0.17, -0.125) * s, M.steel())
		"coat":
			for sx in [-1, 1]: M.box(root, Vector3(0.2, 0.7, 0.04) * s, Vector3(0.11 * sx, -0.3, 0.13) * s, M.cloth(Color(0.16, 0.17, 0.18)), Vector3(8, 0, 0))
			M.box(chest, Vector3(0.52, 0.34, 0.3) * s, Vector3(0, 0.14, 0.01) * s, M.cloth(Color(0.16, 0.17, 0.18)))
			M.box(head, Vector3(0.14, 0.04, 0.1) * s, Vector3(0, 0.05, -0.08) * s, M.cloth(Color(0.6, 0.6, 0.6)))
		"pc":
			M.box(chest, Vector3(0.5, 0.36, 0.3) * s, Vector3(0, 0.14, 0) * s, M.cloth(Color(0.35, 0.25, 0.15)))
			M.box(head, Vector3(0.2, 0.05, 0.02) * s, Vector3(0, 0.17, -0.125) * s, M.iron())
		"dummy":
			M.cyl(head, 0.14 * s, 0.2 * s, Vector3(0, 0.16, 0) * s, M.rust())

func _plates(chest: Node3D, bars: int, b: float) -> void:
	plates.clear()
	for i in bars:
		var row = []
		for k in 4:
			var m = M.box(chest, Vector3(0.1 * b, 0.075, 0.03) * s, Vector3((-0.165 + k * 0.11) * b, 0.26 - i * 0.09, -0.155 * b) * s, M.steel())
			row.append(m)
		plates.append(row)

# bar 的剩餘比例 → 護板顯示
func set_bar(bar: int, frac: float) -> void:
	for i in plates.size():
		for k in 4:
			var want = true
			if i < bar: want = false
			elif i == bar: want = frac > k * 0.25 + 0.001
			var m = plates[i][k]
			if m.visible and not want:
				m.visible = false
				if is_inside_tree(): Fx.gib(m.global_position, Vector3(randf_range(-2, 2), 3, randf_range(-2, 2)) - global_transform.basis.z * 2.0, Vector3(0.1, 0.07, 0.03) * s, M.steel())
			elif not m.visible and want: m.visible = true

func play(anim: String, wu: float, act: float, rec: float) -> void:
	var a = POSES.get(anim, POSES["swing_r"])
	if not a.has("wu"): a = {"wu": a, "hit": a}
	action = {"wu": a["wu"], "hit": a["hit"], "t": 0.0, "twu": wu, "tact": act, "trec": rec}

func stop() -> void: action = null
func pose(n: String) -> void: hold = n

func flinch(dir: Vector3) -> void:
	flinch_t = 0.3; flinch_dir = dir

func _tp(pose_d: Dictionary, k: String):
	return pose_d.get(k, null)

func _process(d: float) -> void:
	if dead and hold == "": return
	breath += d
	walk += d * (4.0 + move_speed * 2.2) * (1.0 if move_speed > 0.2 else 0.0)
	var tgt = {}
	var idle = POSES["idle"]
	for k in idle: tgt[k] = Vector3(idle[k][0], idle[k][1], idle[k][2])
	# 走路
	var ws = clamp(move_speed / 4.0, 0.0, 1.4)
	if ws > 0.05:
		var sw = sin(walk)
		tgt["hip_r"] = Vector3(8 + 34 * sw * ws, 0, 4); tgt["hip_l"] = Vector3(8 - 34 * sw * ws, 0, -4)
		tgt["kn_r"] = Vector3(-14 - 46 * max(0.0, -cos(walk)) * ws, 0, 0); tgt["kn_l"] = Vector3(-14 - 46 * max(0.0, cos(walk)) * ws, 0, 0)
		tgt["sh_l"] = Vector3(6 + 22 * sw * ws, 0, -10); tgt["spine"] = Vector3(8 + 4 * ws, 0, 0)
		tgt["root_y"] = abs(cos(walk)) * 0.04 * ws
	tgt["chest"] = Vector3(sin(breath * 1.6) * 1.5, 0, 0)
	var rate = 10.0
	if hold != "" and POSES.has(hold):
		var hp = POSES[hold]
		for k in hp: tgt[k] = hp[k] if typeof(hp[k]) != TYPE_ARRAY else Vector3(hp[k][0], hp[k][1], hp[k][2])
		rate = 9.0
	if action != null:
		action["t"] += d
		var t = action["t"]; var ps; var w
		if t < action["twu"]:
			ps = action["wu"]; rate = 3.2 / max(0.08, action["twu"]) + 3.0
		elif t < action["twu"] + action["tact"] + 0.1:
			ps = action["hit"]; rate = 34.0
		else:
			ps = null; rate = 6.0
			if t > action["twu"] + action["tact"] + action["trec"]: action = null
		if ps != null:
			for k in ps: tgt[k] = ps[k] if typeof(ps[k]) != TYPE_ARRAY else Vector3(ps[k][0], ps[k][1], ps[k][2])
	if wobble > 0.25:
		var wv = (wobble - 0.25) * 16.0
		tgt["spine"] = tgt.get("spine", Vector3.ZERO) + Vector3(sin(breath * 5.0) * wv + wv, 0, cos(breath * 3.7) * wv)
		tgt["head"] = tgt.get("head", Vector3.ZERO) + Vector3(wv * 1.2, 0, 0)
	if flinch_t > 0:
		flinch_t -= d
		tgt["spine"] = tgt.get("spine", Vector3.ZERO) + Vector3(-25, 0, 18) * (flinch_t / 0.3)
		tgt["head"] = tgt.get("head", Vector3.ZERO) + Vector3(-20, 15, 0) * (flinch_t / 0.3)
	var a = clamp(rate * d, 0.0, 1.0)
	for k in cur:
		if k == "root_y" or k == "root_x":
			cur[k] = lerp(float(cur[k]), float(tgt.get(k, 0.0)), a); continue
		if not J.has(k) or k.begins_with("hand"): continue
		cur[k] = cur[k].lerp(tgt.get(k, Vector3.ZERO), a)
		J[k].rotation_degrees = cur[k]
	J["root"].position.y = base_y + cur["root_y"] * s
	J["root"].rotation_degrees.x = cur["root_x"]

func head_pos() -> Vector3: return J["head"].global_position + Vector3(0, 0.15 * s, 0)
func chest_pos() -> Vector3: return J["chest"].global_position + Vector3(0, 0.1 * s, 0)

# 斷肢：把關節子樹變成剛體飛出去
func sever(joint: String, impulse: Vector3) -> void:
	if severed.has(joint) or not J.has(joint): return
	severed[joint] = true
	var j: Node3D = J[joint]
	var gt = j.global_transform
	var rb = RigidBody3D.new(); rb.collision_layer = 0; rb.collision_mask = 1; rb.mass = 4.0
	var cs = CollisionShape3D.new(); var sh = CapsuleShape3D.new(); sh.radius = 0.09 * s; sh.height = 0.4 * s; cs.shape = sh; rb.add_child(cs)
	if joint == "head":
		var bs = SphereShape3D.new(); bs.radius = 0.14 * s; cs.shape = bs; cs.position = Vector3(0, 0.15, 0) * s
	else: cs.position = Vector3(0, -0.2, 0) * s
	Fx.root.add_child(rb); rb.global_transform = gt
	var stump = j.get_parent()
	var lp = j.position
	j.get_parent().remove_child(j); rb.add_child(j); j.transform = Transform3D.IDENTITY
	rb.linear_velocity = impulse; rb.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	Fx.gush(rb, Vector3.ZERO, 3.0, 0.5); Fx.gush(stump, lp, 5.0, 1.0)
	M.ball(stump, 0.07 * s, lp, M.blood())
	Fx.blood(gt.origin, impulse.normalized(), 50)
	Snd.at("splat", gt.origin, 2.0)
	for k in J.keys():
		if J[k] == j or j.is_ancestor_of(J[k]): J.erase(k); cur.erase(k)
