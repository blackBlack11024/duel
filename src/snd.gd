extends Node
# 音效、音樂、架空語音。
var cache = {}
var mus: AudioStreamPlayer
var amb: AudioStreamPlayer
var voice: AudioStreamPlayer
var cur_mus = ""
var cur_amb = ""
var speak_id = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mus = AudioStreamPlayer.new(); add_child(mus)
	amb = AudioStreamPlayer.new(); add_child(amb)
	voice = AudioStreamPlayer.new(); add_child(voice)

func st(n: String) -> AudioStream:
	if cache.has(n): return cache[n]
	var s = null
	for ext in [".wav", ".ogg"]:
		var p = "res://audio/" + n + ext
		if ResourceLoader.exists(p):
			s = load(p); break
	if s is AudioStreamOggVorbis: s.loop = true
	cache[n] = s; return s

func play(n: String, db: float = 0.0, pitch: float = 1.0) -> void:
	var s = st(n)
	if s == null: return
	var p = AudioStreamPlayer.new(); p.stream = s; p.volume_db = db; p.pitch_scale = pitch * randf_range(0.96, 1.04)
	add_child(p); p.play(); p.finished.connect(p.queue_free)

func at(n: String, pos: Vector3, db: float = 0.0, pitch: float = 1.0) -> void:
	var s = st(n)
	if s == null or Fx.root == null or not is_instance_valid(Fx.root): return
	var p = AudioStreamPlayer3D.new(); p.stream = s; p.volume_db = db; p.pitch_scale = pitch * randf_range(0.95, 1.05); p.unit_size = 6.0; p.max_distance = 80.0
	Fx.root.add_child(p); p.global_position = pos; p.play(); p.finished.connect(p.queue_free)

func music(n: String) -> void:
	if n == cur_mus: return
	cur_mus = n
	var tw = create_tween(); tw.tween_property(mus, "volume_db", -50.0, 0.6)
	await tw.finished
	if n == "": mus.stop(); return
	mus.stream = st(n); mus.volume_db = -50.0; mus.play()
	create_tween().tween_property(mus, "volume_db", linear_to_db(max(0.001, float(G.opt("music")))) - 6.0, 1.5)

func ambience(n: String, db: float = -14.0) -> void:
	if n == cur_amb: return
	cur_amb = n
	if n == "": amb.stop(); return
	amb.stream = st(n); amb.volume_db = db; amb.play()

# 架空語言：依字數播放音節。回傳預估秒數。
func speak(v: String, text: String) -> float:
	speak_id += 1
	var my = speak_id
	if v == "": return 0.8 + text.length() * 0.09
	var n = 0
	for ch in text:
		if not (ch in "，。？！…—、 「」（）"): n += 1
	var syl = clamp(int(n * 0.75), 1, 40)
	_run_speak(v, text, syl, my)
	return 0.5 + syl * 0.16

func _run_speak(v: String, text: String, syl: int, my: int) -> void:
	var h = hash(text)
	for i in syl:
		if my != speak_id: return
		var s = st("v_%s_%d" % [v, (h + i * 7 + (i * i) % 5) % 10])
		if s == null: return
		voice.stream = s; voice.pitch_scale = 1.0 + 0.06 * sin(i * 1.7 + h % 7); voice.volume_db = -3.0; voice.play()
		await get_tree().create_timer(s.get_length() * 0.82, true, false, true).timeout
		if i % 5 == 4: await get_tree().create_timer(0.12, true, false, true).timeout

func hush() -> void:
	speak_id += 1; voice.stop()
