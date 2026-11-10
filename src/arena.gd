extends Node3D
# 六個場地，全部程序化。提供出生點、邊界、與各場機關。
const M = preload("res://src/mat.gd")
var kind = ""
var half = Vector2(12, 18)       # 可活動範圍半寬/半長
var round_r = 0.0                # >0 表示圓形場地
var p_spawn = Vector3(0, 0, 12)
var b_spawn = Vector3(0, 0, -8)
var env: Environment
var sun: DirectionalLight3D
var plates = []                  # sluice
var plate_t = []
var walls = []                   # sluice 的可縮牆
var water_mesh: MeshInstance3D
var water_level = 0
var water_y = -0.4
var world
var gate_drips = []
var wheel_pos = Vector3.ZERO
var crowd = []

func build(k: String, w = null) -> void:
	kind = k; world = w
	var we = WorldEnvironment.new(); env = Environment.new(); we.environment = env; add_child(we)
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.5, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.5, 0.48, 0.5); env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 0.8
	env.glow_enabled = true; env.glow_intensity = 0.5; env.glow_bloom = 0.12; env.glow_hdr_threshold = 1.1
	env.fog_enabled = true; env.fog_light_color = Color(0.6, 0.52, 0.42); env.fog_density = 0.012
	env.adjustment_enabled = true; env.adjustment_contrast = 1.15; env.adjustment_saturation = 0.9
	sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-62, 25, 0); sun.light_energy = 1.5; sun.light_color = Color(1.0, 0.9, 0.75)
	sun.shadow_enabled = true; sun.directional_shadow_max_distance = 60.0; add_child(sun)
	match k:
		"spillway": _spillway()
		"gallery": _gallery()
		"engine": _engine()
		"silt": _silt()
		"sluice": _sluice()
		"cistern": _cistern()
		"hub": pass
	_cool()
	_dust()
	_crowd_build()

func _floor(sx: float, sz: float, mat: Material, y: float = 0.0) -> void:
	M.solid(self, Vector3(sx, 1.0, sz), Vector3(0, y - 0.5, 0), mat)

func _wall(size: Vector3, pos: Vector3, mat: Material = null) -> StaticBody3D:
	return M.solid(self, size, pos, mat if mat else M.concrete())

func _box_room(hx: float, hz: float, h: float, mat: Material = null) -> void:
	_wall(Vector3(1, h, hz * 2 + 2), Vector3(-hx - 0.5, h * 0.5, 0), mat); _wall(Vector3(1, h, hz * 2 + 2), Vector3(hx + 0.5, h * 0.5, 0), mat)
	_wall(Vector3(hx * 2 + 2, h, 1), Vector3(0, h * 0.5, -hz - 0.5), mat); _wall(Vector3(hx * 2 + 2, h, 1), Vector3(0, h * 0.5, hz + 0.5), mat)

func _lamp(pos: Vector3, col: Color, e: float, r: float, shadow: bool = false) -> OmniLight3D:
	var l = OmniLight3D.new(); l.light_color = col; l.light_energy = e; l.omni_range = r; l.shadow_enabled = shadow; add_child(l); l.position = pos
	M.ball(self, 0.12, pos, M.glow(col, 4.0)); return l

func _shaft(pos: Vector3, r: float, h: float, col: Color = Color(1, 0.92, 0.75, 0.07)) -> void:
	var mi = M.cyl(self, r * 1.5, h, pos + Vector3(0, h * 0.5, 0), M.ghost(col), Vector3.ZERO, r * 0.6, 16)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _dust() -> void:
	var p = CPUParticles3D.new(); p.amount = 120; p.lifetime = 9.0; p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; p.emission_box_extents = Vector3(half.x, 4, half.y)
	var q = SphereMesh.new(); q.radius = 0.012; q.height = 0.024; q.radial_segments = 4; q.rings = 2; p.mesh = q; p.material_override = M.ghost(Color(1, 0.95, 0.8, 0.5))
	p.gravity = Vector3(0, -0.03, 0); p.initial_velocity_max = 0.25; p.spread = 180.0; p.position = Vector3(0, 4, 0); add_child(p)

# ---- 群眾：三個 MultiMesh（身體、頭、手），會跳、會舉手 ----
var crowd_pts = []      # [pos, phase, speed, yaw]
var crowd_mm = []
var cheer_v = 0.0
var crowd_t = 0.0
var crowd_snd: AudioStreamPlayer

func _stand(x: float, z0: float, z1: float, y0: float, tiers: int, face: float) -> void:
	# 階梯看台，靠牆。face = 面向場內的 x 方向（+1 或 -1）
	for k in tiers:
		var px = x - face * k * 1.0; var py = y0 + k * 0.9
		M.box(self, Vector3(1.0, 0.25, abs(z1 - z0)), Vector3(px, py, (z0 + z1) * 0.5), M.rust(Color(0.3, 0.26, 0.22)))
		if k == 0: M.box(self, Vector3(0.08, 0.08, abs(z1 - z0)), Vector3(px + face * 0.5, py + 1.0, (z0 + z1) * 0.5), M.iron())
		var n = int(abs(z1 - z0) / 0.62)
		for q in n:
			if randf() < 0.12: continue
			crowd_pts.append([Vector3(px + randf_range(-0.25, 0.25), py + 0.12, min(z0, z1) + 0.3 + q * 0.62 + randf_range(-0.12, 0.12)), randf() * TAU, randf_range(5.0, 9.0), PI * 0.5 * face + randf_range(-0.4, 0.4)])
	for q in int(abs(z1 - z0) / 4.0) + 1:
		M.box(self, Vector3(0.25, y0, 0.25), Vector3(x + face * 0.3, y0 * 0.5, min(z0, z1) + q * 4.0), M.iron())

func _ring_stand(r: float, y: float) -> void:
	for q in 28:
		var a = q * TAU / 28.0
		var b = M.box(self, Vector3(3.0, 0.25, 1.4), Vector3(cos(a) * r, y, sin(a) * r), M.rust(Color(0.3, 0.26, 0.22))); b.rotation.y = -a + PI / 2
		var rl = M.box(self, Vector3(3.0, 0.08, 0.08), Vector3(cos(a) * (r - 0.65), y + 1.0, sin(a) * (r - 0.65)), M.iron()); rl.rotation.y = -a + PI / 2
		for k in 4:
			var a2 = a + (k - 1.5) * 0.05
			crowd_pts.append([Vector3(cos(a2) * (r - randf_range(0.0, 0.5)), y + 0.12, sin(a2) * (r - randf_range(0.0, 0.5))), randf() * TAU, randf_range(5.0, 9.0), atan2(cos(a2), sin(a2)) + PI])

func _crowd_build() -> void:
	if crowd_pts.is_empty(): return
	var meshes = []
	var cm = CapsuleMesh.new(); cm.radius = 0.19; cm.height = 1.15; cm.radial_segments = 6; cm.rings = 2; meshes.append(cm)
	var sm = SphereMesh.new(); sm.radius = 0.13; sm.height = 0.26; sm.radial_segments = 6; sm.rings = 3; meshes.append(sm)
	var bm = BoxMesh.new(); bm.size = Vector3(0.62, 0.09, 0.09); meshes.append(bm)
	for k in 3:
		var mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = meshes[k]; mm.instance_count = crowd_pts.size()
		var mi = MultiMeshInstance3D.new(); mi.multimesh = mm
		var mt = StandardMaterial3D.new(); mt.vertex_color_use_as_albedo = true; mt.roughness = 0.9; mi.material_override = mt
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mi); crowd_mm.append(mm)
		for i in crowd_pts.size():
			var c = Color.from_hsv(randf_range(0.0, 0.6), randf_range(0.05, 0.3), randf_range(0.12, 0.38))
			if k == 1: c = Color.from_hsv(0.06, 0.4, randf_range(0.35, 0.6))
			mm.set_instance_color(i, c)
	crowd_snd = AudioStreamPlayer.new(); crowd_snd.stream = Snd.st("amb_crowd"); crowd_snd.volume_db = -60.0; add_child(crowd_snd); crowd_snd.play()
	_crowd_pose(0.0)

func cheer(a: float) -> void:
	if crowd_pts.is_empty(): return
	cheer_v = min(1.6, cheer_v + a)

func _crowd_pose(d: float) -> void:
	crowd_t += d
	var amp = 0.03 + cheer_v * 0.3
	for i in crowd_pts.size():
		var p = crowd_pts[i]
		var hop = abs(sin(crowd_t * p[2] * (0.4 + min(1.0, cheer_v)) + p[1])) * amp
		var b = Basis(Vector3.UP, p[3] + sin(crowd_t * 0.7 + p[1]) * 0.15)
		var o: Vector3 = p[0] + Vector3(0, hop, 0)
		crowd_mm[0].set_instance_transform(i, Transform3D(b, o + Vector3(0, 0.58, 0)))
		crowd_mm[1].set_instance_transform(i, Transform3D(b, o + Vector3(0, 1.28, 0)))
		var up = clamp(cheer_v * 1.2 + 0.25 * sin(crowd_t * 2.0 + p[1] * 3.0) - 0.15, 0.0, 1.0)
		crowd_mm[2].set_instance_transform(i, Transform3D(b, o + Vector3(0, 0.95 + up * 0.62, 0)))

# ---- 佈景 ----
func _dress(pipes: bool = true, banners: bool = true) -> void:
	var hx = half.x; var hz = half.y
	for i in 46:
		var side = i % 4
		var p = Vector3(randf_range(-hx, hx), 0, randf_range(-hz, hz))
		if side == 0: p.x = -hx + randf_range(0.2, 1.0)
		elif side == 1: p.x = hx - randf_range(0.2, 1.0)
		elif side == 2: p.z = -hz + randf_range(0.2, 1.0)
		else: p.z = hz - randf_range(0.2, 1.0)
		var sz = Vector3(randf_range(0.15, 0.7), randf_range(0.1, 0.45), randf_range(0.15, 0.7))
		M.box(self, sz, p + Vector3(0, sz.y * 0.4, 0), M.concrete(Color(0.36, 0.34, 0.31)) if i % 3 else M.rust(), Vector3(randf_range(-20, 20), randf() * 360, randf_range(-20, 20)))
	for i in 22:
		var st = M.cyl(self, randf_range(0.4, 1.6), 0.004, Vector3(randf_range(-hx + 1, hx - 1), 0.004 + i * 0.0004, randf_range(-hz + 1, hz - 1)), M.mk("stain", Color(0.1, 0.085, 0.07), 0.6, 0.0), Vector3.ZERO, -1.0, 10)
		st.scale = Vector3(1, 1, randf_range(0.5, 1.4)); st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if pipes:
		for sx in [-1.0, 1.0]:
			for k in 3: M.cyl(self, 0.16 + k * 0.05, hz * 2.0, Vector3(sx * (hx - 0.3), 2.6 + k * 0.55, 0), M.rust(Color(0.33, 0.25, 0.2)) if k != 1 else M.iron(), Vector3(90, 0, 0))
			for q in int(hz / 3.0): M.box(self, Vector3(0.5, 2.2, 0.12), Vector3(sx * (hx - 0.3), 3.0, -hz + 2.0 + q * 6.0), M.iron())
	if banners:
		var cols = [Color(0.55, 0.12, 0.08), Color(0.6, 0.5, 0.2), Color(0.15, 0.3, 0.38), Color(0.5, 0.45, 0.4)]
		for q in 6:
			var sx2 = -1.0 if q % 2 == 0 else 1.0
			var z = -hz + 3.0 + int(q / 2.0) * (hz * 2.0 - 6.0) / 2.0
			var bn = M.box(self, Vector3(0.04, 3.2, 1.7), Vector3(sx2 * (hx - 0.08), 5.6, z), M.cloth(cols[q % 4]), Vector3(0, 0, randf_range(-2, 2)))
			bn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for k in 4: M.box(self, Vector3(0.05, 0.5, 0.12), Vector3(sx2 * (hx - 0.11), 6.2 - (k % 2) * 0.8, z - 0.5 + k * 0.3), M.cloth(Color(0.9, 0.85, 0.7)))
	# 掛燈與鐵鍊
	for q in 4:
		var lp = Vector3(randf_range(-hx * 0.5, hx * 0.5), 6.5, -hz + (q + 0.5) * hz * 0.5)
		M.cyl(self, 0.015, 8.0, lp + Vector3(0, 4.0, 0), M.iron()); M.cyl(self, 0.3, 0.25, lp, M.rust(), Vector3.ZERO, 0.08, 10)
		M.ball(self, 0.09, lp + Vector3(0, -0.12, 0), M.glow(Color(1, 0.85, 0.55), 3.0))

func _props(list: Array) -> void:
	if world == null: return
	for it in list:
		var pos: Vector3 = it[1]
		if pos.distance_to(p_spawn) < 2.5 or pos.distance_to(b_spawn) < 2.5: continue
		world.spawn_prop(it[0], pos, randf() * TAU if it[0] != "planks" else (it[2] if it.size() > 2 else 0.0))

func _scatter(n: int, types: Array) -> Array:
	var out = []
	for i in n:
		var p = Vector3.ZERO
		for tries in 8:
			p = clamp_pos(Vector3(randf_range(-half.x, half.x), 0, randf_range(-half.y, half.y)))
			if abs(p.x) > 2.2 or abs(p.z) > half.y * 0.75: break
		out.append([types[randi() % types.size()], p])
		if randf() < 0.4: out.append([types[randi() % types.size()], clamp_pos(p + Vector3(randf_range(-1.1, 1.1), 0, randf_range(-1.1, 1.1)))])
	return out

func _spillway() -> void:
	half = Vector2(11, 17); p_spawn = Vector3(0, 0, 12); b_spawn = Vector3(0, 0, -9)
	_floor(24, 36, M.concrete(Color(0.36, 0.33, 0.29)))
	_box_room(11, 17, 40)
	for sx in [-5.5, 5.5]:
		for sz in [-6.0, 6.0]: _wall(Vector3(1.6, 14, 1.6), Vector3(sx, 7, sz), M.concrete(Color(0.42, 0.4, 0.38)))
	_stand(-10.4, -15, 15, 4.2, 4, 1.0); _stand(10.4, -15, 15, 4.2, 4, -1.0); _dress()
	_props(_scatter(9, ["crate", "barrel", "pot", "crate", "redbarrel"]))
	_shaft(Vector3(0, 0, -2), 6, 40)
	sun.rotation_degrees = Vector3(-66, 18, 0); sun.light_energy = 1.5
	env.background_color = Color(0.85, 0.75, 0.6); env.fog_density = 0.018
	# 閘門
	_wall(Vector3(8, 9, 0.6), Vector3(0, 4.5, -17.2), M.rust()); 
	for i in 5: M.box(self, Vector3(0.3, 9, 0.2), Vector3(-3.2 + i * 1.6, 4.5, -16.8), M.iron())
	_lamp(Vector3(-9, 5, 10), Color(1, 0.6, 0.3), 2.5, 14); _lamp(Vector3(9, 5, -10), Color(1, 0.6, 0.3), 2.5, 14)

func _gallery() -> void:
	half = Vector2(6, 26); p_spawn = Vector3(0, 0, 20); b_spawn = Vector3(0, 0, -14)
	_floor(14, 54, M.concrete(Color(0.4, 0.4, 0.42)))
	_box_room(6, 26, 11, M.concrete(Color(0.36, 0.36, 0.38)))
	_wall(Vector3(14, 1, 54), Vector3(0, 11.5, 0), M.concrete(Color(0.3, 0.3, 0.32)))
	for i in 9:
		M.box(self, Vector3(12.5, 0.35, 0.35), Vector3(0, 6.0, -24 + i * 6.0), M.rust())
		if i % 2 == 0: _lamp(Vector3(randf_range(-3, 3), 5.4, -24 + i * 6.0), Color(1.0, 0.85, 0.55), 6.0, 18, i == 4)
	for z in [-18.0, -6.0, 6.0, 16.0]:
		var sx = 3.6 if int(z) % 12 == 0 else -3.6
		_wall(Vector3(1.8, 1.3, 1.4), Vector3(sx, 0.65, z), M.wood()); _wall(Vector3(1.0, 0.9, 1.0), Vector3(sx * 0.9, 1.75, z), M.wood(Color(0.5, 0.35, 0.2)))
	for i in 3: M.cyl(self, 0.25, 54, Vector3(-5.6, 2.0 + i * 0.7, 0), M.rust(), Vector3(90, 0, 0))
	_stand(-5.5, -22, 22, 3.4, 1, 1.0); _stand(5.5, -22, 22, 3.4, 1, -1.0); _dress(false, false)
	_props(_scatter(8, ["crate", "crate", "barrel", "pot"]))
	sun.visible = false; env.background_color = Color(0.03, 0.03, 0.04); env.ambient_light_energy = 0.8; env.fog_light_color = Color(0.2, 0.2, 0.25); env.fog_density = 0.03

func _engine() -> void:
	round_r = 14.0; half = Vector2(14, 14); p_spawn = Vector3(0, 0, 11); b_spawn = Vector3(0, 0, -9)
	_floor(32, 32, M.concrete(Color(0.36, 0.38, 0.36)))
	for i in 20:
		var a = i * TAU / 20.0
		_wall(Vector3(4.8, 18, 1.2), Vector3(cos(a) * 14.9, 9, sin(a) * 14.9), M.concrete(Color(0.3, 0.33, 0.3))).rotation.y = -a + PI / 2
	var gen = StaticBody3D.new(); add_child(gen); var cs = CollisionShape3D.new(); var sh = CylinderShape3D.new(); sh.radius = 2.6; sh.height = 5.0; cs.shape = sh; cs.position = Vector3(0, 2.5, 0); gen.add_child(cs)
	M.cyl(gen, 2.6, 3.0, Vector3(0, 1.5, 0), M.rust(Color(0.3, 0.38, 0.32)), Vector3.ZERO, -1.0, 20); M.cyl(gen, 1.6, 2.0, Vector3(0, 4.0, 0), M.iron(), Vector3.ZERO, 1.0, 16)
	for i in 8: M.box(gen, Vector3(0.3, 2.6, 0.5), Vector3(cos(i * TAU / 8) * 2.7, 1.4, sin(i * TAU / 8) * 2.7), M.iron(), Vector3(0, -rad_to_deg(i * TAU / 8), 0))
	_shaft(Vector3(0, 0, 4), 5, 18, Color(0.85, 1.0, 0.8, 0.09))
	_ring_stand(13.2, 5.5)
	_props(_scatter(9, ["pot", "pot", "crate", "barrel"]))
	sun.rotation_degrees = Vector3(-80, 0, 0); sun.light_energy = 1.4; sun.light_color = Color(0.85, 1.0, 0.8)
	_wall(Vector3(32, 1, 12), Vector3(0, 18.5, -10), M.concrete(Color(0.2, 0.2, 0.2))); _wall(Vector3(32, 1, 10), Vector3(0, 18.5, 12), M.concrete(Color(0.2, 0.2, 0.2)))
	env.background_color = Color(0.5, 0.6, 0.5); env.ambient_light_color = Color(0.45, 0.55, 0.47); env.ambient_light_energy = 0.8; env.fog_light_color = Color(0.3, 0.38, 0.3); env.fog_density = 0.035
	_lamp(Vector3(-9, 3, -8), Color(1, 0.7, 0.3), 2.0, 10); _lamp(Vector3(9, 3, 8), Color(1, 0.7, 0.3), 2.0, 10)

func _silt() -> void:
	half = Vector2(14, 14); p_spawn = Vector3(0, 0, 11); b_spawn = Vector3(0, 0, -10)
	_floor(30, 30, M.mud())
	_box_room(14, 14, 16, M.concrete(Color(0.45, 0.42, 0.36)))
	for ix in range(-2, 3):
		for iz in range(-2, 3):
			if (ix + iz) % 2 == 0 and not (ix == 0 and abs(iz) == 2):
				var horiz = (ix * 3 + iz) % 3 != 0
				_wall(Vector3(3.4 if horiz else 0.5, 0.75, 0.5 if horiz else 3.4), Vector3(ix * 5.0, 0.37, iz * 5.0), M.concrete(Color(0.4, 0.37, 0.32)))
	sun.rotation_degrees = Vector3(-50, -40, 0); sun.light_energy = 1.5; sun.light_color = Color(1, 0.82, 0.6)
	env.background_color = Color(0.75, 0.62, 0.45); env.fog_light_color = Color(0.7, 0.58, 0.42); env.fog_density = 0.022
	_stand(-13.4, -12, 12, 3.6, 4, 1.0); _stand(13.4, -12, 12, 3.6, 4, -1.0); _dress(false)
	_props(_scatter(8, ["crate", "pot", "planks", "redbarrel", "barrel"]))

func _sluice() -> void:
	half = Vector2(11, 11); p_spawn = Vector3(0, 0, 8.5); b_spawn = Vector3(0, 0, -7)
	_floor(26, 26, M.steel(Color(0.3, 0.31, 0.33)))
	for i in 6: M.box(self, Vector3(22, 0.03, 0.12), Vector3(0, 0.02, -10 + i * 4.0), M.rust())
	for i in 4:
		var a = i * PI / 2
		var wall = _wall(Vector3(24, 14, 1), Vector3(sin(a) * 11.5, 7, cos(a) * 11.5), M.rust(Color(0.4, 0.33, 0.2))); wall.rotation.y = a; walls.append(wall)
	# 十二塊可升降鋼板
	for i in 12:
		var a2 = i * TAU / 12.0; var r = 6.0 if i % 2 == 0 else 3.4
		var pl = M.solid(self, Vector3(2.6, 3.2, 0.3), Vector3(cos(a2) * r, -1.7, sin(a2) * r), M.rust(Color(0.7, 0.58, 0.15)))
		pl.rotation.y = -a2 + PI / 2; plates.append(pl); plate_t.append(0.0)
		M.box(self, Vector3(2.7, 0.02, 0.4), Vector3(cos(a2) * r, 0.012, sin(a2) * r), M.iron(), Vector3(0, rad_to_deg(-a2) + 90, 0))
	_stand(-10.6, -9, 9, 6.0, 2, 1.0); _stand(10.6, -9, 9, 6.0, 2, -1.0)
	_props(_scatter(6, ["barrel", "redbarrel", "crate"]))
	sun.visible = false; env.background_color = Color(0.05, 0.04, 0.03); env.ambient_light_color = Color(0.6, 0.52, 0.4); env.ambient_light_energy = 1.0
	env.fog_light_color = Color(0.3, 0.24, 0.12); env.fog_density = 0.015
	for sx in [-8.0, 8.0]:
		for sz in [-8.0, 8.0]: _lamp(Vector3(sx * 0.7, 7, sz * 0.7), Color(1, 0.82, 0.45), 8.0, 24, sx > 0 and sz > 0)
	_wall(Vector3(26, 1, 26), Vector3(0, 14.5, 0), M.iron())

func _cistern() -> void:
	half = Vector2(11, 17); p_spawn = Vector3(0, 0, 13); b_spawn = Vector3(0, 0, -10)
	_floor(24, 36, M.concrete(Color(0.3, 0.33, 0.35)))
	_box_room(11, 17, 12, M.concrete(Color(0.26, 0.3, 0.32)))
	_wall(Vector3(24, 1, 36), Vector3(0, 12.5, 0), M.concrete(Color(0.2, 0.22, 0.24)))
	for sx in [-6.0, 6.0]:
		for i in 5:
			var col = StaticBody3D.new(); add_child(col); col.position = Vector3(sx, 0, -12 + i * 6.0)
			var cs = CollisionShape3D.new(); var sh = CylinderShape3D.new(); sh.radius = 0.7; sh.height = 12; cs.shape = sh; cs.position = Vector3(0, 6, 0); col.add_child(cs)
			M.cyl(col, 0.7, 12, Vector3(0, 6, 0), M.concrete(Color(0.33, 0.36, 0.38)), Vector3.ZERO, -1.0, 12)
	water_mesh = M.box(self, Vector3(22, 0.02, 34), Vector3(0, water_y, 0), M.water())
	_dress(true, false)
	_props(_scatter(7, ["pot", "pot", "barrel", "crate"]))
	wheel_pos = Vector3(0, 1.3, -16.3)
	var wh = M.cyl(self, 0.9, 0.12, wheel_pos, M.rust(Color(0.5, 0.15, 0.1)), Vector3(90, 0, 0), -1.0, 16); wh.name = "wheel"
	for i in 4: M.box(self, Vector3(1.8, 0.1, 0.1), wheel_pos + Vector3(0, 0, 0.05), M.iron(), Vector3(0, 0, i * 45))
	M.box(self, Vector3(6, 7, 0.5), Vector3(0, 3.5, -16.8), M.rust(Color(0.25, 0.3, 0.3)))
	sun.visible = false; env.background_color = Color(0.01, 0.02, 0.03); env.ambient_light_color = Color(0.4, 0.55, 0.6); env.ambient_light_energy = 0.9
	env.fog_light_color = Color(0.1, 0.2, 0.22); env.fog_density = 0.02
	for z in [-12.0, -4.0, 4.0, 12.0]: _lamp(Vector3(0, 6.5, z), Color(0.6, 0.9, 0.95), 7.0, 22, z == 4.0)
	_lamp(Vector3(0, 3.5, -15.5), Color(1, 0.75, 0.4), 2.5, 9)

# ---------------- 大結構 ----------------
var spinners = []        # [node, 轉速]
var swayers = []         # [node, 原位, 頻率, 軸, 幅度]
var sway_t = 0.0

func _gear(pos: Vector3, r: float, rot: Vector3, speed: float, mat: Material = null) -> Node3D:
	var g = Node3D.new(); add_child(g); g.position = pos; g.rotation_degrees = rot
	var mt = mat if mat else M.rust(Color(0.34, 0.26, 0.2))
	M.cyl(g, r, 0.45, Vector3.ZERO, mt, Vector3.ZERO, -1.0, 24); M.cyl(g, r * 0.28, 0.7, Vector3.ZERO, M.iron(), Vector3.ZERO, -1.0, 12)
	var n = int(r * 7.0)
	for k in n:
		var a = k * TAU / n
		M.box(g, Vector3(r * 0.2, 0.42, r * 0.26), Vector3(cos(a) * r * 1.05, 0, sin(a) * r * 1.05), mt, Vector3(0, -rad_to_deg(a), 0))
	for k in 5:
		var a2 = k * TAU / 5.0
		M.cyl(g, r * 0.13, 0.5, Vector3(cos(a2) * r * 0.62, 0, sin(a2) * r * 0.62), M.mk("hole", Color(0.03, 0.03, 0.03), 1.0, 0.0), Vector3.ZERO, -1.0, 10)
	spinners.append([g, speed]); return g

func _arch(z: float, w: float, base: float, rise: float, thick: float, depth: float, mat: Material) -> void:
	var n = 12
	for k in n:
		var a0 = PI * k / n; var a1 = PI * (k + 1) / n
		var p0 = Vector3(cos(a0) * w * 0.5, base + sin(a0) * rise, z); var p1 = Vector3(cos(a1) * w * 0.5, base + sin(a1) * rise, z)
		var seg = M.box(self, Vector3(p0.distance_to(p1) + 0.1, thick, depth), (p0 + p1) * 0.5, mat)
		seg.rotation.z = atan2(p1.y - p0.y, p1.x - p0.x)
	for sx in [-1.0, 1.0]: M.box(self, Vector3(thick, base, depth), Vector3(sx * w * 0.5, base * 0.5, z), mat)

func _chain(top: Vector3, length: float, hook: bool = true) -> Node3D:
	var c = Node3D.new(); add_child(c); c.position = top
	var n = int(length / 0.35)
	for k in n: M.box(c, Vector3(0.1, 0.3, 0.05), Vector3(0, -k * 0.35, 0), M.iron(), Vector3(0, 90.0 * (k % 2), 0))
	if hook:
		M.cyl(c, 0.3, 0.5, Vector3(0, -length - 0.2, 0), M.rust(Color(0.6, 0.5, 0.1))); M.box(c, Vector3(0.12, 0.9, 0.12), Vector3(0, -length - 0.9, 0), M.iron())
		M.box(c, Vector3(0.6, 0.12, 0.12), Vector3(0.25, -length - 1.35, 0), M.iron()); M.box(c, Vector3(0.12, 0.4, 0.12), Vector3(0.5, -length - 1.15, 0), M.iron())
	swayers.append([c, top, randf_range(0.5, 0.9), "z", 0.035]); return c

func _fall(pos: Vector3, w: float, h: float) -> void:
	var ps = CPUParticles3D.new(); ps.amount = int(60 * w); ps.lifetime = sqrt(2.0 * h / 14.0); ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; ps.emission_box_extents = Vector3(w * 0.5, 0.1, 0.1)
	var q = BoxMesh.new(); q.size = Vector3(0.05, 0.7, 0.05); ps.mesh = q; ps.material_override = M.ghost(Color(0.7, 0.9, 1.0, 0.45)); ps.gravity = Vector3(0, -14, 0); ps.initial_velocity_max = 0.5
	add_child(ps); ps.position = pos

func _slit(pos: Vector3, size: Vector3, col: Color) -> void:
	M.box(self, size, pos, M.glow(col, 2.5)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _truss(a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var m = M.cyl(self, r, a.distance_to(b), (a + b) * 0.5, mat, Vector3.ZERO, -1.0, 6)
	m.look_at_from_position((a + b) * 0.5, b, Vector3.UP if abs((b - a).normalized().y) < 0.99 else Vector3.RIGHT); m.rotate_object_local(Vector3.RIGHT, PI * 0.5)

func _cool() -> void:
	var hx = half.x; var hz = half.y
	match kind:
		"spillway":
			# 壩面：斜撐扶壁、六道小閘、兩個大齒輪、頭上的斷橋與吊鉤、兩側的出水管
			for x in [-9.6, -5.4, 5.4, 9.6]:
				M.box(self, Vector3(1.3, 44, 3.2), Vector3(x, 20, -16.2), M.concrete(Color(0.36, 0.34, 0.31)), Vector3(-5, 0, 0))
			var opened = int(G.S["gate"])
			for k in 6:
				var gx = -8.0 + k * 3.2
				M.box(self, Vector3(2.2, 3.4, 0.4), Vector3(gx, 14.0, -16.9), M.rust(Color(0.28, 0.3, 0.3)))
				M.box(self, Vector3(2.6, 0.4, 0.7), Vector3(gx, 15.9, -16.8), M.iron())
				_slit(Vector3(gx, 12.0, -16.75), Vector3(1.4, 0.16, 0.1), Color(0.4, 0.85, 1.0) if k < opened else Color(0.35, 0.08, 0.05))
				if k < opened: _fall(Vector3(gx, 12.2, -16.4), 1.6, 12.0)
			_gear(Vector3(-5.6, 5.0, -16.6), 2.6, Vector3(90, 0, 0), 0.25); _gear(Vector3(5.6, 5.0, -16.6), 2.6, Vector3(90, 0, 0), -0.25)
			_gear(Vector3(-8.4, 8.2, -16.7), 1.5, Vector3(90, 0, 0), -0.45); _gear(Vector3(8.4, 8.2, -16.7), 1.5, Vector3(90, 0, 0), 0.45)
			for sx in [-1.0, 1.0]:
				M.box(self, Vector3(8.2, 1.2, 3.0), Vector3(sx * 7.2, 18.0, 3.0), M.concrete(Color(0.4, 0.38, 0.35)), Vector3(0, 0, sx * -4.0))
				for k in 5: M.cyl(self, 0.04, randf_range(1.5, 3.2), Vector3(sx * 3.0 - sx * k * 0.05, 17.6 - k * 0.1, 1.8 + k * 0.6), M.rust(), Vector3(0, 0, sx * randf_range(50, 80)))
				for z in [-9.0, 9.0]:
					M.cyl(self, 2.2, 3.5, Vector3(sx * 10.2, 13.0, z), M.rust(Color(0.3, 0.24, 0.2)), Vector3(0, 0, 90), -1.0, 18)
					M.cyl(self, 1.9, 3.6, Vector3(sx * 10.1, 13.0, z), M.mk("hole", Color(0.03, 0.03, 0.03), 1.0, 0.0), Vector3(0, 0, 90), -1.0, 18)
					_fall(Vector3(sx * 8.6, 11.3, z), 0.6, 7.0)
				for y in [22.0, 31.0]: M.box(self, Vector3(1.6, 0.8, hz * 2.0), Vector3(sx * (hx - 0.5), y, 0), M.concrete(Color(0.33, 0.31, 0.29)))
			_chain(Vector3(0, 30, -3), 20.0)
			_chain(Vector3(-4, 30, 7), 14.0, false); _chain(Vector3(5, 30, 10), 17.0, false)
			# 中央排水溝
			M.box(self, Vector3(1.6, 0.02, hz * 2.0 - 4), Vector3(0, 0.011, 0), M.iron())
			for k in int(hz * 2.0 - 4): M.box(self, Vector3(1.6, 0.03, 0.12), Vector3(0, 0.02, -hz + 2.5 + k), M.rust())
		"gallery":
			# 拱肋隧道、兩端的大風扇、側牆光縫
			for k in 9: _arch(-24.0 + k * 6.0, 12.4, 6.0, 4.6, 0.6, 0.9, M.concrete(Color(0.3, 0.3, 0.32)))
			for z in [-25.4, 25.4]:
				_slit(Vector3(0, 5.2, z + (0.3 if z < 0 else -0.3) * -1.0), Vector3(8.4, 8.4, 0.1), Color(0.75, 0.85, 1.0))
				var fan = Node3D.new(); add_child(fan); fan.position = Vector3(0, 5.2, z + (0.9 if z < 0 else -0.9)); fan.rotation_degrees = Vector3(90, 0, 0)
				for b in 5:
					var bl = M.box(fan, Vector3(4.0, 0.12, 1.3), Vector3(cos(b * TAU / 5) * 2.1, 0, sin(b * TAU / 5) * 2.1), M.iron(), Vector3(18, -rad_to_deg(b * TAU / 5), 0))
				M.cyl(fan, 0.7, 0.6, Vector3.ZERO, M.rust()); spinners.append([fan, 0.9 if z < 0 else -0.6])
				for b in 4: M.box(self, Vector3(9.0, 0.25, 0.25), Vector3(0, 5.2, z + (0.5 if z < 0 else -0.5)), M.iron(), Vector3(0, 0, b * 45.0))
			for k in 8:
				for sx in [-1.0, 1.0]: _slit(Vector3(sx * 5.97, 8.2, -21.0 + k * 6.0), Vector3(0.06, 1.6, 0.5), Color(1.0, 0.75, 0.4))
			for k in 5: _chain(Vector3(randf_range(-4, 4), 10.5, -20.0 + k * 10.0), randf_range(2.0, 4.0), k % 2 == 0)
		"engine":
			# 頭頂緩慢旋轉的巨大轉子、拉向牆面的纜線、牆上的肋柱
			var rotor = Node3D.new(); add_child(rotor); rotor.position = Vector3(0, 13.5, 0)
			for b in 6: M.box(rotor, Vector3(11.5, 0.35, 1.9), Vector3(cos(b * TAU / 6) * 6.0, 0, sin(b * TAU / 6) * 6.0), M.rust(Color(0.25, 0.32, 0.28)), Vector3(14, -rad_to_deg(b * TAU / 6), 0))
			M.cyl(rotor, 1.4, 2.2, Vector3.ZERO, M.iron(), Vector3.ZERO, -1.0, 16); M.cyl(rotor, 0.5, 9.0, Vector3(0, -4.2, 0), M.steel())
			spinners.append([rotor, 0.22])
			for k in 10:
				var a = k * TAU / 10.0
				_truss(Vector3(cos(a) * 1.4, 5.0, sin(a) * 1.4), Vector3(cos(a) * 14.0, 9.5 + (k % 2) * 2.0, sin(a) * 14.0), 0.05, M.iron())
				var rib = M.box(self, Vector3(1.0, 18, 1.4), Vector3(cos(a + 0.16) * 14.0, 9, sin(a + 0.16) * 14.0), M.concrete(Color(0.24, 0.27, 0.25))); rib.rotation.y = -a
				_slit(Vector3(cos(a + 0.16) * 13.4, 3.0, sin(a + 0.16) * 13.4), Vector3(0.3, 0.3, 0.3), Color(1.0, 0.6, 0.2))
			for k in 3: _gear(Vector3(cos(k * 2.1 + 0.5) * 13.9, 4.0 + k * 1.5, sin(k * 2.1 + 0.5) * 13.9), 1.8, Vector3(90, rad_to_deg(-(k * 2.1 + 0.5)) + 90, 0), 0.3 * (1 if k % 2 == 0 else -1), M.rust(Color(0.25, 0.3, 0.26)))
		"silt":
			# 角落的塔式起重機、吊在場中央上空的抓斗、傾倒的管段
			var T = Vector3(-12.0, 0, -12.0)
			for sx in [-0.8, 0.8]:
				for sz in [-0.8, 0.8]: M.box(self, Vector3(0.2, 19, 0.2), T + Vector3(sx, 9.5, sz), M.rust(Color(0.7, 0.55, 0.1)))
			for k in 9:
				_truss(T + Vector3(-0.8, k * 2.0, -0.8), T + Vector3(0.8, k * 2.0 + 2.0, -0.8), 0.06, M.rust(Color(0.7, 0.55, 0.1)))
				_truss(T + Vector3(0.8, k * 2.0, 0.8), T + Vector3(-0.8, k * 2.0 + 2.0, 0.8), 0.06, M.rust(Color(0.7, 0.55, 0.1)))
				_truss(T + Vector3(-0.8, k * 2.0, 0.8), T + Vector3(-0.8, k * 2.0 + 2.0, -0.8), 0.06, M.rust(Color(0.7, 0.55, 0.1)))
			var tip = Vector3(1.0, 17.5, 1.0)
			_truss(T + Vector3(0, 18.5, 0), tip, 0.18, M.rust(Color(0.7, 0.55, 0.1))); _truss(T + Vector3(0, 19.5, 0), tip + Vector3(0, 0.6, 0), 0.1, M.rust(Color(0.7, 0.55, 0.1)))
			for k in 8: _truss(T.lerp(tip, k / 8.0) + Vector3(0, 18.5 - k * 0.12, 0) - Vector3(0, T.lerp(tip, k / 8.0).y, 0), T.lerp(tip, (k + 1) / 8.0) + Vector3(0, 19.5, 0) - Vector3(0, T.lerp(tip, (k + 1) / 8.0).y, 0), 0.05, M.iron())
			M.box(self, Vector3(2.4, 2.0, 2.4), T + Vector3(0, 19.5, 0), M.rust(Color(0.3, 0.3, 0.3)))
			var ch = _chain(tip, 8.0, false)
			var bk = Node3D.new(); ch.add_child(bk); bk.position = Vector3(0, -8.6, 0)
			M.box(bk, Vector3(2.2, 0.3, 2.2), Vector3.ZERO, M.iron())
			for sx in [-1.0, 1.0]: M.box(bk, Vector3(0.15, 1.6, 2.2), Vector3(sx * 0.9, -0.8, 0), M.rust(), Vector3(0, 0, sx * 22.0))
			M.cyl(self, 1.3, 7.0, Vector3(9.5, 1.3, -11.0), M.concrete(Color(0.42, 0.4, 0.36)), Vector3(90, 30, 0), -1.0, 14)
			M.cyl(self, 1.1, 7.1, Vector3(9.5, 1.3, -11.0), M.mk("hole", Color(0.03, 0.03, 0.03), 1.0, 0.0), Vector3(90, 30, 0), -1.0, 14)
			for z in [-13.6, 13.6]:
				for k in 3: M.box(self, Vector3(hx * 2.0, 1.2, 1.0), Vector3(0, 4.0 + k * 3.5, z + (0.4 if z > 0 else -0.4) * -k * 0.0), M.concrete(Color(0.38, 0.35, 0.3)))
		"sluice":
			# 牆上咬合的大齒輪、四角升降的配重塊、警示條紋
			for k in 4:
				var a = k * PI / 2
				var wp = Vector3(sin(a) * 10.9, 0, cos(a) * 10.9); var along = Vector3(cos(a), 0, -sin(a))
				_gear(wp + along * 3.2 + Vector3(0, 9.0, 0), 3.0, Vector3(90, rad_to_deg(a), 0), 0.3, M.rust(Color(0.4, 0.33, 0.12)))
				_gear(wp - along * 2.6 + Vector3(0, 10.2, 0), 2.4, Vector3(90, rad_to_deg(a), 0), -0.375, M.rust(Color(0.3, 0.25, 0.2)))
				for q in 11:
					M.box(self, Vector3(1.0, 0.6, 0.08), wp * 0.985 + along * (q * 2.0 - 10.0) + Vector3(0, 0.3, 0), M.mk("haz" + str(q % 2), Color(0.85, 0.7, 0.05) if q % 2 == 0 else Color(0.05, 0.05, 0.05), 0.7, 0.2), Vector3(0, rad_to_deg(a), 0))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var top = Vector3(sx * 9.6, 13.5, sz * 9.6)
					var cw = Node3D.new(); add_child(cw); cw.position = top + Vector3(0, -5.5, 0)
					M.box(cw, Vector3(1.4, 2.2, 1.4), Vector3.ZERO, M.concrete(Color(0.3, 0.28, 0.25))); M.box(cw, Vector3(1.5, 0.2, 1.5), Vector3(0, 0.6, 0), M.rust(Color(0.7, 0.55, 0.1)))
					for q in 22: M.box(cw, Vector3(0.1, 0.3, 0.05), Vector3(0, 1.2 + q * 0.35, 0), M.iron(), Vector3(0, 90.0 * (q % 2), 0))
					swayers.append([cw, cw.position, randf_range(0.25, 0.45), "y", 2.2])
			for q in 5: M.box(self, Vector3(22, 0.5, 0.5), Vector3(0, 13.4, -9.0 + q * 4.5), M.iron())
		"cistern":
			# 柱間的尖拱、肋形天花、遠端兩道瀑布、高處的光縫
			for i in 5:
				var z = -12.0 + i * 6.0
				_arch(z, 12.0, 7.0, 4.6, 0.5, 0.8, M.concrete(Color(0.28, 0.32, 0.34)))
				for sx in [-1.0, 1.0]:
					for q in 5:
						var a = PI * 0.5 * q / 5.0; var a1 = PI * 0.5 * (q + 1) / 5.0
						var p0 = Vector3(sx * (6.0 + sin(a) * 5.0), 7.0 + (1.0 - cos(a)) * -0.0 + sin(a) * 0.0 + cos(a) * 4.6 - 4.6 + 4.6, z)
						var p1 = Vector3(sx * (6.0 + sin(a1) * 5.0), 7.0 + cos(a1) * 4.6, z)
						p0.y = 7.0 + cos(a) * 4.6
						var sg = M.box(self, Vector3(p0.distance_to(p1) + 0.1, 0.4, 0.7), (p0 + p1) * 0.5, M.concrete(Color(0.26, 0.3, 0.32))); sg.rotation.z = atan2(p1.y - p0.y, p1.x - p0.x)
					M.cyl(self, 0.95, 0.5, Vector3(sx * 6.0, 0.25, z), M.concrete(Color(0.3, 0.33, 0.35)), Vector3.ZERO, -1.0, 12); M.cyl(self, 1.0, 0.6, Vector3(sx * 6.0, 7.2, z), M.concrete(Color(0.3, 0.33, 0.35)), Vector3.ZERO, 0.7, 12)
			for sx in [-1.0, 1.0]:
				M.box(self, Vector3(2.4, 0.5, 1.0), Vector3(sx * 5.0, 9.6, -16.4), M.rust(Color(0.25, 0.3, 0.3)))
				_fall(Vector3(sx * 5.0, 9.3, -15.9), 2.0, 9.5)
				for k in 4: _slit(Vector3(sx * 10.97, 9.5, -11.0 + k * 7.5), Vector3(0.06, 2.4, 0.7), Color(0.6, 0.9, 1.0))
			_gear(wheel_pos + Vector3(-2.6, 2.2, -0.3), 1.6, Vector3(90, 0, 0), 0.2, M.rust(Color(0.25, 0.3, 0.3))); _gear(wheel_pos + Vector3(2.6, 2.2, -0.3), 1.6, Vector3(90, 0, 0), -0.2, M.rust(Color(0.25, 0.3, 0.3)))
			for k in 4: _chain(Vector3(randf_range(-9, 9), 12, randf_range(-12, 12)), randf_range(2.5, 5.0), false)

# ---------------- 機關 ----------------
func _process(d: float) -> void:
	for sp in spinners:
		if is_instance_valid(sp[0]): sp[0].rotate_object_local(Vector3.UP, sp[1] * d)
	sway_t += d
	for sw in swayers:
		if is_instance_valid(sw[0]):
			if sw[3] == "y": sw[0].position.y = sw[1].y + sin(sway_t * sw[2]) * sw[4]
			else: sw[0].rotation.z = sin(sway_t * sw[2]) * sw[4]
	if crowd_mm.is_empty(): return
	cheer_v = max(0.0, cheer_v - d * 0.55)
	_crowd_pose(d)
	crowd_snd.volume_db = lerp(crowd_snd.volume_db, -26.0 + min(1.0, cheer_v) * 22.0, clamp(d * 6.0, 0, 1))
	crowd_snd.pitch_scale = 1.0 + min(1.0, cheer_v) * 0.25

func _physics_process(d: float) -> void:
	for i in plates.size():
		if plate_t[i] > 0:
			plate_t[i] -= d
			plates[i].position.y = move_toward(plates[i].position.y, 1.6, 9.0 * d)
		elif plate_t[i] > -900: plates[i].position.y = move_toward(plates[i].position.y, -1.7, 4.0 * d)
		else: plates[i].position.y = move_toward(plates[i].position.y, 1.6, 9.0 * d)
	if water_mesh:
		var ty = [-0.4, 0.14, 0.48][water_level]
		water_y = move_toward(water_y, ty, 0.25 * d); water_mesh.position.y = water_y
		if world:
			for cb in world.combatants(): cb.water = water_level if water_y > 0.05 else 0

func raise_around(pos: Vector3) -> void:
	if world and world.boss and world.boss.parts_off.has("box"): return
	var order = range(plates.size())
	order.sort_custom(func(a, b): return plates[a].position.distance_squared_to(Vector3(pos.x, plates[a].position.y, pos.z)) < plates[b].position.distance_squared_to(Vector3(pos.x, plates[b].position.y, pos.z)))
	for i in 4:
		if plate_t[order[i]] > -900: plate_t[order[i]] = 7.0
	Snd.at("gate", pos, -2.0, 1.6)

func shrink(ph: int) -> void:
	# 每過一條，外牆往內推、外圈鋼板永久升起
	var r = 11.0 - 2.6 * ph
	half = Vector2(r, r)
	for i in walls.size():
		var a = i * PI / 2
		create_tween().tween_property(walls[i], "position", Vector3(sin(a) * (r + 0.5), 7, cos(a) * (r + 0.5)), 2.5)
	if ph >= 2:
		for i in plates.size():
			if i % 2 == 0: plate_t[i] = -999.0
	Snd.play("gate", 0.0)

func raise_water() -> void:
	water_level = min(2, water_level + 1); Snd.play("gate", -3.0, 0.8); Snd.ambience("amb_water", -8.0)

func clamp_pos(p: Vector3) -> Vector3:
	if round_r > 0:
		var v = Vector2(p.x, p.z)
		if v.length() > round_r - 1.5: v = v.normalized() * (round_r - 1.5)
		if kind == "engine" and v.length() < 4.0: v = (v.normalized() if v.length() > 0.1 else Vector2(1, 0)) * 4.0
		return Vector3(v.x, 0, v.y)
	return Vector3(clamp(p.x, -half.x + 1.2, half.x - 1.2), 0, clamp(p.z, -half.y + 1.2, half.y - 1.2))

func random_spot(center: Vector3, rmin: float, rmax: float) -> Vector3:
	var a = randf() * TAU; var r = randf_range(rmin, rmax)
	return clamp_pos(center + Vector3(cos(a) * r, 0, sin(a) * r))

func far_spot(from: Vector3, cur: Vector3) -> Vector3:
	var best = cur; var bd = 0.0
	for i in 10:
		var p = clamp_pos(Vector3(randf_range(-half.x, half.x), 0, randf_range(-half.y, half.y)))
		var dd = p.distance_to(from)
		if dd > bd and p.distance_to(cur) > 5.0:
			bd = dd; best = p
	return best
