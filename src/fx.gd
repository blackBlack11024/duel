extends Node
# 特效：血、火花、頓幀、慢動作、鏡頭震動。
const M = preload("res://src/mat.gd")
signal screen_blood(amount: float)
signal screen_flash(col: Color, t: float)
var root: Node3D = null
var shake = 0.0
var fov_kick = 0.0
var pools = []
var _stop_id = 0
var net_safe = false   # 連線時不改 time_scale

func _process(d: float) -> void:
	var rd = d / max(Engine.time_scale, 0.01)
	shake = max(0.0, shake - rd * 2.5)
	fov_kick = lerp(fov_kick, 0.0, clamp(rd * 8.0, 0.0, 1.0))

func ok() -> bool: return root != null and is_instance_valid(root)

func hitstop(dur: float, scale: float = 0.03) -> void:
	if net_safe: return
	_stop_id += 1
	var my = _stop_id
	Engine.time_scale = scale
	await get_tree().create_timer(dur, true, false, true).timeout
	if my == _stop_id: Engine.time_scale = 1.0

func slowmo(scale: float, dur: float) -> void: hitstop(dur, scale)

func add_shake(a: float) -> void: shake = min(1.5, shake + a)

func _parts(pos: Vector3, n: int, mat: Material, size: float, life: float, vel: float, dir: Vector3, spread: float, grav: float = -14.0) -> CPUParticles3D:
	var p = CPUParticles3D.new(); p.one_shot = true; p.explosiveness = 0.95; p.amount = n; p.lifetime = life
	var q = SphereMesh.new(); q.radius = size; q.height = size * 2; q.radial_segments = 4; q.rings = 2; p.mesh = q; p.material_override = mat
	p.direction = dir; p.spread = spread; p.initial_velocity_min = vel * 0.3; p.initial_velocity_max = vel
	p.gravity = Vector3(0, grav, 0); p.scale_amount_min = 0.3; p.scale_amount_max = 1.4
	root.add_child(p); p.global_position = pos; p.emitting = true
	var tw = p.create_tween(); tw.tween_interval(life + 0.5); tw.tween_callback(p.queue_free)
	return p

func blood(pos: Vector3, dir: Vector3, n: int = 24) -> void:
	if not ok(): return
	_parts(pos, n, M.blood(), 0.035, 0.9, 6.0, dir if dir.length() > 0.1 else Vector3.UP, 45.0)
	_parts(pos, max(4, int(n / 3.0)), M.blood(), 0.07, 0.7, 3.0, Vector3.UP, 70.0)
	for i in clamp(int(n / 8.0), 1, 6):
		pool(pos + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2)) + dir * randf_range(0, 1.5), randf_range(0.15, 0.5))

func pool(pos: Vector3, r: float = 0.3) -> void:
	if not ok(): return
	var sp = root.get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos + Vector3(0, -4, 0), 1)
	var h = sp.intersect_ray(q)
	if h.is_empty(): return
	var mi = MeshInstance3D.new(); var c = CylinderMesh.new(); c.top_radius = 1.0; c.bottom_radius = 1.0; c.height = 0.004; c.radial_segments = 9; mi.mesh = c
	mi.material_override = M.blood(); root.add_child(mi)
	mi.global_position = h["position"] + Vector3(0, 0.006 + randf() * 0.004, 0); mi.rotation.y = randf() * 6.0
	mi.scale = Vector3(0.05, 1, 0.05)
	create_tween().tween_property(mi, "scale", Vector3(r * randf_range(0.7, 1.3), 1, r * randf_range(0.7, 1.3)), randf_range(0.4, 1.5)).set_delay(0.25)
	pools.append(mi)
	if pools.size() > 160:
		var o = pools.pop_front()
		if is_instance_valid(o): o.queue_free()

# 持續噴血（斷肢、處決）
func gush(parent: Node3D, lpos: Vector3, dur: float, amount: float = 1.0) -> void:
	if not ok(): return
	var p = CPUParticles3D.new(); p.amount = int(40 * amount); p.lifetime = 0.8; p.local_coords = false
	var q = SphereMesh.new(); q.radius = 0.03; q.height = 0.06; q.radial_segments = 4; q.rings = 2; p.mesh = q; p.material_override = M.blood()
	p.direction = Vector3.UP; p.spread = 25.0; p.initial_velocity_min = 2.0; p.initial_velocity_max = 5.5; p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.4; p.scale_amount_max = 1.6
	parent.add_child(p); p.position = lpos
	var steps = int(dur / 0.25)
	for i in steps:
		await get_tree().create_timer(0.25).timeout
		if not is_instance_valid(p): return
		pool(p.global_position + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)), randf_range(0.2, 0.7))
	if is_instance_valid(p):
		p.emitting = false
		var tw = p.create_tween(); tw.tween_interval(1.0); tw.tween_callback(p.queue_free)

func sparks(pos: Vector3, col: Color = Color(1, 0.8, 0.3), n: int = 16, vel: float = 7.0) -> void:
	if not ok(): return
	_parts(pos, n, M.glow(col, 5.0), 0.015, 0.45, vel, Vector3.UP, 180.0, -10.0)
	flash(pos, col, 3.0, 0.12)

func dust(pos: Vector3, n: int = 10, col: Color = Color(0.5, 0.45, 0.4, 0.5)) -> void:
	if not ok(): return
	var m = M.ghost(col)
	var p = _parts(pos, n, m, 0.12, 1.2, 2.0, Vector3.UP, 80.0, -1.0)
	p.scale_amount_max = 3.0

func flash(pos: Vector3, col: Color, energy: float, dur: float, rng: float = 6.0) -> void:
	if not ok(): return
	var l = OmniLight3D.new(); l.light_color = col; l.light_energy = energy; l.omni_range = rng; root.add_child(l); l.global_position = pos
	var tw = l.create_tween(); tw.tween_property(l, "light_energy", 0.0, dur); tw.tween_callback(l.queue_free)

func tracer(a: Vector3, b: Vector3, col: Color = Color(1, 0.9, 0.6), w: float = 0.012) -> void:
	if not ok() or a.distance_to(b) < 0.2: return
	var mi = MeshInstance3D.new(); var c = BoxMesh.new(); c.size = Vector3(w, w, a.distance_to(b)); mi.mesh = c
	var m = M.ghost(col); mi.material_override = m; root.add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP if abs((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw = mi.create_tween(); tw.tween_property(m, "albedo_color:a", 0.0, 0.12); tw.tween_callback(mi.queue_free)

func gib(pos: Vector3, vel: Vector3, size: Vector3, mat: Material, life: float = 6.0) -> RigidBody3D:
	if not ok(): return null
	var rb = RigidBody3D.new(); rb.collision_layer = 0; rb.collision_mask = 1; rb.mass = 0.5
	var cs = CollisionShape3D.new(); var sh = BoxShape3D.new(); sh.size = size; cs.shape = sh; rb.add_child(cs)
	M.box(rb, size, Vector3.ZERO, mat); root.add_child(rb); rb.global_position = pos
	rb.linear_velocity = vel; rb.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	var tw = rb.create_tween(); tw.tween_interval(life); tw.tween_callback(rb.queue_free)
	return rb

func gore(pos: Vector3, dir: Vector3, n: int = 6) -> void:
	# 肉塊
	for i in n:
		gib(pos, dir * randf_range(1, 4) + Vector3(randf_range(-3, 3), randf_range(2, 6), randf_range(-3, 3)), Vector3.ONE * randf_range(0.04, 0.1), M.blood(), 8.0)
	blood(pos, dir, 40); screen_blood.emit(0.5)

func explosion(pos: Vector3, r: float) -> void:
	if not ok(): return
	Snd.at("explosion", pos, 4.0)
	flash(pos + Vector3(0, 0.5, 0), Color(1, 0.6, 0.2), 14.0, 0.35, r * 3.0)
	_parts(pos, 40, M.glow(Color(1, 0.5, 0.1), 4.0), 0.12, 0.5, r * 4.0, Vector3.UP, 180.0, -3.0)
	dust(pos, 30, Color(0.2, 0.18, 0.16, 0.7))
	var mi = MeshInstance3D.new(); var sm = SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; mi.mesh = sm
	var m = M.ghost(Color(1, 0.7, 0.3, 0.7)); mi.material_override = m; root.add_child(mi); mi.global_position = pos; mi.scale = Vector3.ONE * 0.3
	var tw = mi.create_tween(); tw.set_parallel(); tw.tween_property(mi, "scale", Vector3.ONE * r, 0.22); tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(mi.queue_free)
	add_shake(0.8)
