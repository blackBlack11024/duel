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
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.5, 0.48, 0.5); env.ambient_light_energy = 0.4
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
	_dust()

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

func _crowd(z0: float, z1: float, x: float, y: float) -> void:
	# 檢修走道上的觀眾（剪影）
	_wall(Vector3(2.0, 0.3, abs(z1 - z0)), Vector3(x, y, (z0 + z1) * 0.5), M.rust())
	var n = int(abs(z1 - z0) / 1.1)
	for i in n:
		var c = M.cap(self, 0.22, randf_range(1.3, 1.8), Vector3(x + randf_range(-0.5, 0.5), y + 0.95, min(z0, z1) + i * 1.1 + randf_range(-0.3, 0.3)), M.cloth(Color(0.12, 0.1, 0.09)))
		crowd.append(c)

func _spillway() -> void:
	half = Vector2(11, 17); p_spawn = Vector3(0, 0, 12); b_spawn = Vector3(0, 0, -9)
	_floor(24, 36, M.concrete(Color(0.36, 0.33, 0.29)))
	_box_room(11, 17, 40)
	for sx in [-5.5, 5.5]:
		for sz in [-6.0, 6.0]: _wall(Vector3(1.6, 14, 1.6), Vector3(sx, 7, sz), M.concrete(Color(0.42, 0.4, 0.38)))
	_crowd(-15, 15, -10.2, 9.0); _crowd(-15, 15, 10.2, 9.0)
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
		if i % 2 == 0: _lamp(Vector3(randf_range(-3, 3), 5.4, -24 + i * 6.0), Color(1.0, 0.85, 0.55), 3.2, 13, i == 4)
	for z in [-18.0, -6.0, 6.0, 16.0]:
		var sx = 3.6 if int(z) % 12 == 0 else -3.6
		_wall(Vector3(1.8, 1.3, 1.4), Vector3(sx, 0.65, z), M.wood()); _wall(Vector3(1.0, 0.9, 1.0), Vector3(sx * 0.9, 1.75, z), M.wood(Color(0.5, 0.35, 0.2)))
	for i in 3: M.cyl(self, 0.25, 54, Vector3(-5.6, 2.0 + i * 0.7, 0), M.rust(), Vector3(90, 0, 0))
	sun.visible = false; env.background_color = Color(0.03, 0.03, 0.04); env.ambient_light_energy = 0.28; env.fog_light_color = Color(0.2, 0.2, 0.25); env.fog_density = 0.03

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
	sun.rotation_degrees = Vector3(-80, 0, 0); sun.light_energy = 1.4; sun.light_color = Color(0.85, 1.0, 0.8)
	_wall(Vector3(32, 1, 12), Vector3(0, 18.5, -10), M.concrete(Color(0.2, 0.2, 0.2))); _wall(Vector3(32, 1, 10), Vector3(0, 18.5, 12), M.concrete(Color(0.2, 0.2, 0.2)))
	env.background_color = Color(0.5, 0.6, 0.5); env.ambient_light_color = Color(0.4, 0.5, 0.42); env.ambient_light_energy = 0.4; env.fog_light_color = Color(0.3, 0.38, 0.3); env.fog_density = 0.035
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
	_crowd(-12, 12, -13.2, 7.0)

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
	sun.visible = false; env.background_color = Color(0.05, 0.04, 0.03); env.ambient_light_color = Color(0.5, 0.42, 0.3); env.ambient_light_energy = 0.3
	env.fog_light_color = Color(0.3, 0.24, 0.12); env.fog_density = 0.03
	for sx in [-8.0, 8.0]:
		for sz in [-8.0, 8.0]: _lamp(Vector3(sx, 8, sz), Color(1, 0.8, 0.35), 3.5, 16, sx > 0 and sz > 0)
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
	wheel_pos = Vector3(0, 1.3, -16.3)
	var wh = M.cyl(self, 0.9, 0.12, wheel_pos, M.rust(Color(0.5, 0.15, 0.1)), Vector3(90, 0, 0), -1.0, 16); wh.name = "wheel"
	for i in 4: M.box(self, Vector3(1.8, 0.1, 0.1), wheel_pos + Vector3(0, 0, 0.05), M.iron(), Vector3(0, 0, i * 45))
	M.box(self, Vector3(6, 7, 0.5), Vector3(0, 3.5, -16.8), M.rust(Color(0.25, 0.3, 0.3)))
	sun.visible = false; env.background_color = Color(0.01, 0.02, 0.03); env.ambient_light_color = Color(0.3, 0.45, 0.5); env.ambient_light_energy = 0.3
	env.fog_light_color = Color(0.08, 0.16, 0.18); env.fog_density = 0.04
	for z in [-12.0, 0.0, 12.0]: _lamp(Vector3(0, 9, z), Color(0.55, 0.85, 0.9), 3.0, 18, z == 0.0)
	_lamp(Vector3(0, 3.5, -15.5), Color(1, 0.75, 0.4), 2.5, 9)

# ---------------- 機關 ----------------
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
