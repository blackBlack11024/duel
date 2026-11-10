extends Node
# 全部靜態資料：武器、零件、Boss、台詞、筆記本。

const MELEE = {
	"laoban": {"name": "老伴", "cls": "blunt", "dmg": 16.0, "post": 20.0, "reach": 2.4, "spd": 1.0, "stab": 0.6, "parry": 0.15, "heavy": 1.0, "dur": 1.0, "cost": 1},
	"banshan": {"name": "半扇", "cls": "blade", "dmg": 22.0, "post": 14.0, "reach": 2.2, "spd": 0.9, "stab": 0.5, "parry": 0.15, "heavy": 1.0, "dur": 1.0, "cost": 2},
	"sanfen": {"name": "三分筋", "cls": "pole", "dmg": 18.0, "post": 16.0, "reach": 3.4, "spd": 1.1, "stab": 0.3, "parry": 0.14, "heavy": 1.0, "dur": 1.0, "cost": 2, "price": 3, "gate": 1},
	"gemi": {"name": "割蜜", "cls": "blade", "dmg": 20.0, "post": 15.0, "reach": 3.0, "spd": 1.05, "stab": 0.45, "parry": 0.15, "heavy": 1.0, "dur": 1.0, "cost": 2},
	"banyuan": {"name": "半圓", "cls": "pole", "dmg": 17.0, "post": 22.0, "reach": 2.6, "spd": 1.0, "stab": 0.8, "parry": 0.16, "heavy": 1.0, "dur": 1.0, "cost": 2},
	"shougong": {"name": "收工", "cls": "blunt", "dmg": 30.0, "post": 40.0, "reach": 2.7, "spd": 1.5, "stab": 0.7, "parry": 0.13, "heavy": 1.0, "dur": 1.0, "cost": 3},
}
const GUNS = {
	"liukong": {"name": "六孔", "cls": "short", "dmg": 26.0, "post": 8.0, "pellets": 1, "spread": 1.5, "recoil": 3.0, "draw": 0.35, "reload": 1.6, "mag": 6, "reserve": 12, "rof": 0.32, "range": 40.0, "rel": 0.0, "snd": "shot_revolver", "cost": 1},
	"duiban": {"name": "對半", "cls": "short", "dmg": 9.0, "post": 6.0, "pellets": 8, "spread": 9.0, "recoil": 8.0, "draw": 0.4, "reload": 1.8, "mag": 2, "reserve": 6, "rof": 0.3, "range": 9.0, "rel": 0.0, "snd": "shot_shotgun", "cost": 2},
	"guahao": {"name": "掛號", "cls": "long", "dmg": 38.0, "post": 10.0, "pellets": 1, "spread": 0.5, "recoil": 4.0, "draw": 0.5, "reload": 2.2, "mag": 5, "reserve": 10, "rof": 0.7, "range": 80.0, "rel": 0.0, "snd": "shot_rifle", "cost": 2},
	"changzui": {"name": "長嘴", "cls": "long", "dmg": 70.0, "post": 30.0, "pellets": 1, "spread": 0.2, "recoil": 7.0, "draw": 0.7, "reload": 2.5, "mag": 1, "reserve": 4, "rof": 1.2, "range": 120.0, "rel": 0.0, "snd": "shot_rifle", "cost": 3, "price": 5, "gate": 2},
	"menlei": {"name": "悶雷", "cls": "long", "dmg": 45.0, "post": 50.0, "pellets": 1, "spread": 1.0, "recoil": 6.0, "draw": 0.5, "reload": 1.8, "mag": 1, "reserve": 4, "rof": 0.5, "range": 30.0, "rel": 0.0, "snd": "thump", "cost": 3},
	"dianming": {"name": "點名", "cls": "long", "dmg": 12.0, "post": 6.0, "pellets": 1, "spread": 2.0, "recoil": 1.5, "draw": 0.45, "reload": 2.0, "mag": 12, "reserve": 24, "rof": 0.16, "range": 30.0, "rel": 0.0, "snd": "shot_air", "cost": 2},
}
const GADGETS = {
	"huizhi": {"name": "回執", "cd": 6.0, "uses": 99, "cost": 2, "axes": ["磅數", "絞盤"]},
	"shuiba": {"name": "睡吧", "cd": 8.0, "uses": 2, "cost": 1, "axes": ["濃度", "範圍"]},
	"jiadang": {"name": "家當", "cd": 10.0, "uses": 2, "cost": 2, "axes": ["兇性", "續航"]},
	"laihui": {"name": "來回", "cd": 1.5, "uses": 3, "cost": 2, "axes": ["磅數", "齒數"], "price": 4, "gate": 2},
	"jieyixia": {"name": "借一下", "cd": 8.0, "uses": 99, "cost": 2, "axes": ["圈數", "容量"], "price": 5, "gate": 3},
	"guodian": {"name": "過電", "cd": 7.0, "uses": 99, "cost": 2, "axes": ["放電", "容量"], "price": 5, "gate": 4},
}
const CORES = {
	"xiejian": {"name": "卸件", "cost": 2}, "guobang": {"name": "過磅", "cost": 1}, "guahao": {"name": "掛號", "cost": 1},
	"fenchao": {"name": "分巢", "cost": 2}, "yanshi": {"name": "延時", "cost": 2}, "gongqi": {"name": "工期", "cost": 3},
}
# 零件：slot -> [選項]。m = 乘數；need = 需要的手藝；c = 廢料價；f = 精件價；t = 水票價
const GUN_PARTS = {
	"barrel": [{"id": "std", "name": "原長"}, {"id": "short", "name": "鋸短", "m": {"draw": 0.7, "spread": 1.6, "range": 0.6}, "c": 15},
		{"id": "long", "name": "重管", "m": {"draw": 1.3, "spread": 0.6, "range": 1.4, "dmg": 1.08}, "c": 30, "need": "barrel"}],
	"rifling": [{"id": "std", "name": "原廠"}, {"id": "fast", "name": "快纏", "m": {"range": 1.3, "spread": 0.8, "rof": 1.12}, "c": 25, "need": "barrel"},
		{"id": "smooth", "name": "滑膛", "m": {"spread": 2.2, "post": 1.35, "dmg": 0.9}, "c": 20, "need": "barrel"}],
	"trigger": [{"id": "std", "name": "原廠"}, {"id": "light", "name": "輕扳機", "m": {"rof": 0.75, "spread": 1.2}, "c": 20},
		{"id": "two", "name": "兩道火", "m": {"spread": 0.8, "rof": 1.15}, "c": 20}],
	"feed": [{"id": "std", "name": "原廠"}, {"id": "quick", "name": "快拔", "m": {"reload": 0.65, "reserve": 0.8}, "c": 25},
		{"id": "ext", "name": "加長", "m": {"mag": 1.5, "reload": 1.25, "draw": 1.1}, "c": 25}],
	"stock": [{"id": "std", "name": "原廠"}, {"id": "cut", "name": "鋸托", "m": {"draw": 0.8, "recoil": 1.5}, "c": 15},
		{"id": "heavy", "name": "配重", "m": {"recoil": 0.55, "draw": 1.2}, "c": 20}],
	"muzzle": [{"id": "std", "name": "無"}, {"id": "brake", "name": "制退", "m": {"recoil": 0.6, "flash": 2.0}, "c": 20},
		{"id": "hider", "name": "消焰", "m": {"recoil": 1.1, "flash": 0.3, "spread": 0.9}, "c": 20}],
	"sight": [{"id": "std", "name": "機械"}, {"id": "optic", "name": "光學", "m": {"aim": 0.4, "tunnel": 2.0}, "c": 30, "f": 1, "need": "barrel"}],
	"powder": [{"id": "std", "name": "標準"}, {"id": "lightp", "name": "減裝", "m": {"dmg": 0.85, "recoil": 0.6, "rof": 0.9}, "c": 15, "need": "powder"},
		{"id": "hot", "name": "強裝", "m": {"dmg": 1.25, "post": 1.2, "recoil": 1.5, "relbad": 5.0}, "c": 30, "f": 1, "need": "powder"}],
	"bullet": [{"id": "std", "name": "包銅"}, {"id": "lead", "name": "軟鉛", "m": {"dmg": 1.15, "post": 0.8}, "c": 20, "need": "powder"},
		{"id": "steel", "name": "鋼芯", "m": {"dmg": 0.9, "post": 1.4}, "c": 20, "need": "powder"},
		{"id": "salt", "name": "岩鹽", "m": {"dmg": 0.5, "post": 1.7}, "c": 15, "need": "chem"}],
}
const MELEE_PARTS = {
	"steel": [{"id": "std", "name": "雜料"}, {"id": "spring", "name": "彈簧鋼", "m": {"dmg": 1.1, "stab": 0.9}, "c": 25},
		{"id": "rebar", "name": "鋼筋", "m": {"post": 1.12, "spd": 1.05}, "c": 20}, {"id": "cast", "name": "鑄鐵", "m": {"post": 1.22, "dmg": 0.9, "dur": 0.7}, "c": 20}],
	"quench": [{"id": "std", "name": "油淬"}, {"id": "air", "name": "風冷", "m": {"dmg": 0.92, "stab": 1.15}, "c": 10},
		{"id": "water", "name": "水淬", "m": {"dmg": 1.2, "dur": 0.6}, "c": 10, "t": 1}],
	"temper": [{"id": "std", "name": "中溫"}, {"id": "low", "name": "低溫", "m": {"dmg": 1.08, "dur": 0.8}, "c": 15, "need": "hydro"},
		{"id": "high", "name": "高溫", "m": {"dmg": 0.94, "stab": 1.1, "dur": 1.3}, "c": 15, "need": "hydro"}],
	"edge": [{"id": "std", "name": "凸磨"}, {"id": "thin", "name": "薄刃", "m": {"dmg": 1.2, "post": 0.85, "dur": 0.7}, "c": 20, "need": "grind"},
		{"id": "chisel", "name": "鑿形", "m": {"dmg": 1.05, "post": 1.1, "spd": 1.05}, "c": 20, "need": "grind"},
		{"id": "dull", "name": "不開刃", "m": {"dmg": 0.7, "post": 1.4}, "c": 10, "need": "grind"}],
	"balance": [{"id": "std", "name": "置中"}, {"id": "front", "name": "前重", "m": {"heavy": 1.25, "spd": 1.12}, "c": 20, "need": "grind"},
		{"id": "back", "name": "後重", "m": {"spd": 0.88, "parry": 1.13, "heavy": 0.9}, "c": 20, "need": "grind"}],
	"grip": [{"id": "std", "name": "原柄"}, {"id": "long", "name": "長柄", "m": {"reach": 1.15, "spd": 1.08}, "c": 15},
		{"id": "wrap", "name": "纏布", "m": {"stab": 1.1, "reach": 0.96}, "c": 10}, {"id": "guard", "name": "護手", "m": {"stab": 1.25, "spd": 1.05}, "c": 20}],
}
const FORGE_SLOTS = ["steel", "quench", "temper", "edge"]
# 數值面板：[key, 圖示, 越小越好?]
const GUN_STATS = [["dmg", "dmg", false], ["post", "post", false], ["range", "range", false], ["spread", "spread", true], ["recoil", "recoil", true], ["draw", "draw", true], ["reload", "reload", true], ["rof", "rof", true], ["mag", "mag", false], ["relbad", "rel", true]]
const MELEE_STATS = [["dmg", "dmg", false], ["post", "post", false], ["reach", "range", false], ["spd", "draw", true], ["stab", "stab", false], ["parry", "parry", false], ["heavy", "heavy", false], ["dur", "dur", false]]
const TECH = {"bao": "grind", "xue": "barrel", "ruan": "chem", "yaling": "powder", "ge": "hydro"}
const ORDER = ["bao", "xue", "ruan", "yaling", "ge", "zha"]

# ---------------- Boss ----------------
# 招式欄位：anim 動作、wu 前搖、act 判定、rec 收招、dmg、post、reach、arc、lunge、unb 不可擋、hyper 霸體、
# kind melee/shot/fn、r [最近,最遠] 可用距離、w 權重、ph 最低階段、part 可卸零件、needs 需要零件、off 零件被卸後的覆寫、next [招, 機率]
const BOSS = {
	"bao": {"name": "老鮑", "title": "秤砣", "voice": "bao", "bars": [330.0, 360.0], "posture": 150.0, "speed": 3.2, "block": 0.25, "dodge": 0.0, "pref": 2.4,
		"melee": "banshan", "gun": "duiban", "arena": "spillway", "odds": 9,
		"rig": {"h": 1.95, "bulk": 1.5, "skin": Color(0.72, 0.5, 0.4), "cloth": Color(0.35, 0.3, 0.25), "acc": "apron"},
		"parts": {"hammer": "擊錘", "lead": "鉛塊"},
		"drops": {"melee": "banshan", "gun": "duiban", "core": "guobang"},
		"moves": {
			"chop": {"anim": "swing_r", "wu": 0.6, "rec": 0.6, "dmg": 18, "post": 20, "reach": 2.8, "r": [0, 3.2], "w": 3, "next": ["chop2", 0.5]},
			"chop2": {"anim": "swing_l", "wu": 0.42, "rec": 0.7, "dmg": 16, "post": 18, "reach": 2.8, "r": [0, 3.2], "w": 0, "next": ["blast", 0.6], "nextph": 1},
			"over": {"anim": "overhead", "wu": 1.0, "rec": 0.9, "dmg": 32, "post": 35, "reach": 3.0, "arc": 60, "unb": true, "r": [0, 3.4], "w": 2, "part": "lead", "off": {"lead": {"wu": 1.4, "unb": false, "dmg": 22}}},
			"shove": {"anim": "kick", "wu": 0.42, "rec": 0.6, "dmg": 8, "post": 28, "reach": 2.1, "r": [0, 2.0], "w": 1.5, "push": 6.0},
			"blast": {"anim": "shoot", "kind": "shot", "wu": 0.8, "rec": 0.8, "dmg": 5, "pellets": 6, "spread": 8, "post": 5, "r": [3.0, 10], "w": 2, "ph": 1, "part": "hammer", "snd": "shot_shotgun"},
			"double": {"anim": "shoot", "kind": "shot", "wu": 1.15, "rec": 1.2, "dmg": 5, "pellets": 13, "spread": 10, "post": 6, "r": [2.5, 8], "w": 1.5, "ph": 1, "needs": "hammer", "part": "hammer", "snd": "shot_shotgun"},
		},
		"lines": {
			"intro": ["新來的？站上來，我看看幾斤。", "三號井的喔。你們那邊上一個來的，骨頭硬，肉少。"],
			"hit": ["這刀算你便宜。", "別躲，躲了我要多走兩步，我腰不好。", "欸，站好。"],
			"parried": ["欸，會還價。", "嘖。"],
			"disarmed": ["欸欸欸，那個要錢的。"],
			"kill": ["不夠秤。回去吃飽再來。"], "kill3": ["又你。我午飯都還沒吃。", "你這樣我很難做生意。"],
			"defeat": ["……行，夠斤兩了。", "閘你自己上去開。輪子在右邊，我爬不動那個梯子。"],
			"laba_intro": "來來來，三號井對秤砣，一賠九！買三號井的過來，我先幫你們點香。",
			"laba_kill": ["三號井躺了。下一個。", "又躺了。有沒有人要改買？沒有？我想也是。", "第{n}次了齁。我香都點完了。"],
			"laba_win": "——欸，贏了。賠九的來領錢，不要擠，我記得你們的臉。",
		}},
	"xue": {"name": "薛快", "title": "郵差", "voice": "xue", "bars": [300.0, 330.0], "posture": 210.0, "speed": 5.2, "block": 0.1, "dodge": 0.35, "pref": 9.0,
		"melee": "knife", "gun": "guahao", "arena": "gallery", "odds": 7,
		"rig": {"h": 1.8, "bulk": 0.8, "skin": Color(0.6, 0.45, 0.35), "cloth": Color(0.25, 0.3, 0.4), "acc": "bag"},
		"parts": {"ratchet": "棘輪", "link": "連桿"},
		"drops": {"gun": "guahao", "gadget": "huizhi", "core": "guahao"},
		"moves": {
			"knife": {"anim": "thrust", "wu": 0.4, "rec": 0.5, "dmg": 14, "post": 12, "reach": 2.5, "r": [0, 2.8], "w": 3, "tag": true, "next": ["slash", 0.5], "lunge": 4.0},
			"slash": {"anim": "swing_l", "wu": 0.38, "rec": 0.6, "dmg": 14, "post": 12, "reach": 2.5, "r": [0, 2.8], "w": 1, "tag": true, "next": ["fly", 0.7]},
			"shot": {"anim": "shoot2", "kind": "shot", "wu": 0.7, "rec": 0.45, "dmg": 24, "post": 10, "r": [5, 60], "w": 4, "part": "link", "off": {"link": {"rec": 1.5}}, "snd": "shot_rifle", "ammo": 1, "next": ["shot", 0.45], "nextph": 1},
			"hookpull": {"anim": "throw", "kind": "fn", "fn": "hook_pull", "wu": 0.6, "rec": 0.3, "r": [5, 15], "w": 1.5, "next": ["knife", 1.0], "snd": "hook"},
			"fly": {"anim": "throw", "kind": "fn", "fn": "fly", "wu": 0.45, "rec": 0.2, "r": [0, 5], "w": 2.5, "needs": "ratchet", "part": "ratchet", "snd": "hook"},
			"reload": {"anim": "reload", "kind": "fn", "fn": "reload", "wu": 1.7, "rec": 0.2, "r": [0, 99], "w": 0, "weak": true, "lunge": -3.0},
		},
		"lines": {
			"intro": ["三號井，收件人一名。", "簽個名就好，很快。"],
			"hit": ["貼好了。", "四十步。三十五。你怎麼不動？", "下一封。"],
			"parried": ["等一下，等一下——"],
			"disarmed": ["欸那個我——", "還我。"],
			"kill": ["送到了。下一站。"], "kill3": ["同一個地址跑四趟。我要跟你們井收錢。", "又是你。我記得這個門牌。"],
			"defeat": ["……退件啊。", "很久沒被退件了。上次是——算了。你走，我坐一下。"],
			"laba_intro": "第二閘！郵差！跑得比你們誰都快，死得也可能比你們誰都快。一賠七！",
			"laba_kill": ["簽收了。抬走。", "郵差今天業績很好齁。", "第{n}封。三號井你是在集點嗎？"],
			"laba_win": "退件！郵差被退件！我做這行二十年沒看過——賠七的排隊！",
		}},
	"ruan": {"name": "阮金枝", "title": "姑婆", "voice": "ruan", "bars": [360.0, 390.0], "posture": 230.0, "speed": 2.6, "block": 0.3, "dodge": 0.1, "pref": 3.5,
		"melee": "gemi", "gun": "", "arena": "engine", "odds": 6,
		"rig": {"h": 1.55, "bulk": 0.9, "skin": Color(0.7, 0.55, 0.45), "cloth": Color(0.3, 0.22, 0.3), "acc": "hat"},
		"parts": {"vent": "風門", "board": "隔板", "ring": "鎖環"},
		"drops": {"melee": "gemi", "gadget": "shuiba", "core": "fenchao"},
		"moves": {
			"reap": {"anim": "swing_r", "wu": 0.65, "rec": 0.6, "dmg": 20, "post": 20, "reach": 3.3, "r": [0, 3.6], "w": 3, "next": ["reap2", 0.5]},
			"reap2": {"anim": "swing_l", "wu": 0.5, "rec": 0.7, "dmg": 20, "post": 20, "reach": 3.3, "r": [0, 3.6], "w": 0, "feint": 0.35},
			"pull": {"anim": "sweep", "wu": 0.8, "rec": 0.5, "dmg": 12, "post": 15, "reach": 4.6, "r": [3.0, 5.0], "w": 2, "needs": "ring", "part": "ring", "pull": 5.0, "next": ["delay", 0.8]},
			"delay": {"anim": "overhead", "wu": 1.0, "rec": 0.9, "dmg": 30, "post": 32, "reach": 3.3, "arc": 70, "r": [0, 3.6], "w": 2, "feint": 0.55},
			"hive": {"anim": "throw", "kind": "fn", "fn": "hive", "wu": 0.9, "rec": 0.5, "r": [3, 99], "w": 2.5},
			"swarm": {"anim": "shoot", "kind": "fn", "fn": "swarm", "wu": 0.9, "rec": 0.6, "r": [5, 99], "w": 2, "needs": "board", "part": "board"},
			"smoke": {"anim": "throw", "kind": "fn", "fn": "smoke", "wu": 0.6, "rec": 0.4, "r": [0, 8], "w": 1.5, "part": "vent"},
		},
		"lines": {
			"intro": ["來，站近一點。姑婆眼睛不好。", "三號井的。你師傅上一季也是站那裡。", "他比你有禮貌，進門還會叫人。"],
			"hit": ["別揮，別揮。牠們怕吵。", "吃過了沒？臉色這麼差。", "慢慢來，不急。"],
			"parried": ["唉唷。"],
			"disarmed": ["這孩子，東西不要亂拆。"],
			"hive_broken": ["唉唷。那個巢我養了兩年。"],
			"kill": ["好了，好了。不痛了。"], "kill3": ["這孩子怎麼講不聽。", "回去睡一覺再來，姑婆等你。"],
			"defeat": ["……手腳比你師傅快。", "蜂箱幫我蓋起來。晚上會冷。"],
			"pc_after": "他最後有說什麼嗎。", "after": "他說扳機太鬆。就這樣。",
			"laba_intro": "第三閘。姑婆。……我不多講，她聽得到。一賠六。",
			"laba_kill": ["唉。跟上一季一樣。", "誰去跟三號井講一聲。", "第{n}次。姑婆的蟲今天吃很飽。"],
			"laba_win": "……贏了？贏了！欸你們有看到嗎！賠六！賠六的過來！",
		}},
	"yaling": {"name": "啞鈴", "title": "", "voice": "", "bars": [330.0, 340.0, 360.0], "posture": 180.0, "speed": 3.4, "block": 0.35, "dodge": 0.15, "pref": 8.0,
		"melee": "banyuan", "gun": "menlei", "arena": "silt", "odds": 5,
		"rig": {"h": 1.75, "bulk": 1.15, "skin": Color(0.55, 0.42, 0.35), "cloth": Color(0.3, 0.33, 0.25), "acc": "pack"},
		"parts": {"crank": "搖柄", "safety": "保險片"},
		"drops": {"melee": "banyuan", "gun": "menlei", "core": "yanshi"},
		"moves": {
			"spade": {"anim": "swing_r", "wu": 0.55, "rec": 0.55, "dmg": 20, "post": 24, "reach": 2.9, "r": [0, 3.2], "w": 3, "next": ["jab", 0.6]},
			"jab": {"anim": "thrust", "wu": 0.4, "rec": 0.6, "dmg": 18, "post": 18, "reach": 3.0, "r": [0, 3.2], "w": 1, "lunge": 4.0, "feint": 0.25},
			"dig": {"anim": "overhead", "wu": 0.9, "rec": 0.8, "dmg": 30, "post": 34, "reach": 3.0, "arc": 60, "r": [0, 3.2], "w": 1.5},
			"lob": {"anim": "shoot", "kind": "fn", "fn": "lob", "wu": 0.7, "rec": 0.5, "r": [4.5, 40], "w": 4, "part": "safety", "snd": "thump", "next": ["lob", 0.5], "nextph": 1},
			"mine": {"anim": "throw", "kind": "fn", "fn": "mine", "wu": 0.8, "rec": 0.5, "r": [3, 40], "w": 2},
			"det": {"anim": "card", "kind": "fn", "fn": "detonate", "wu": 0.5, "rec": 0.3, "r": [0, 99], "w": 0, "part": "crank"},
			"bag": {"anim": "throw", "kind": "fn", "fn": "bag", "wu": 1.2, "rec": 0.8, "r": [0, 99], "w": 0},
		},
		"lines": {
			"intro_cards": ["你好", "不要踩"],
			"hit_cards": ["後面", "等一下", "有講"],
			"kill_card": "有講", "defeat_cards": ["好", "下次不算"],
			"laba_intro": "第四閘，啞鈴。他說你好，叫你不要踩。踩哪裡？我哪知道，我又不下去。一賠五。",
			"laba_kill": ["他說他有講。", "他有講啦，你自己不看。", "第{n}次。他紙板都寫好了，你看，新的。"],
			"laba_win": "他說好。他還說下次不算——欸不算什麼不算，賠五！領錢！",
		}},
	"ge": {"name": "葛蘭", "title": "監工", "voice": "ge", "bars": [450.0, 480.0, 510.0], "posture": 230.0, "speed": 2.8, "block": 0.2, "dodge": 0.0, "pref": 2.8,
		"melee": "shougong", "gun": "dianming", "arena": "sluice", "odds": 4,
		"rig": {"h": 1.9, "bulk": 1.25, "skin": Color(0.75, 0.6, 0.55), "cloth": Color(0.55, 0.45, 0.15), "acc": "exo"},
		"parts": {"tank": "蓄壓瓶", "box": "控制盒", "valve": "回油閥"},
		"drops": {"melee": "shougong", "gun": "dianming", "core": "gongqi"},
		"moves": {
			"pile": {"anim": "swing_r", "wu": 0.8, "rec": 0.7, "dmg": 30, "post": 40, "reach": 3.1, "r": [0, 3.5], "w": 3, "hyper": true, "part": "valve", "off": {"valve": {"rec": 3.0}}, "next": ["pile2", 0.4]},
			"pile2": {"anim": "swing_l", "wu": 0.7, "rec": 0.9, "dmg": 30, "post": 40, "reach": 3.1, "r": [0, 3.5], "w": 0, "hyper": true, "off": {"valve": {"rec": 3.0}}, "feint": 0.3},
			"pound": {"anim": "slam", "wu": 1.1, "rec": 1.1, "dmg": 42, "post": 45, "reach": 3.8, "arc": 360, "unb": true, "hyper": true, "r": [0, 3.6], "w": 2, "part": "tank", "shock": true, "off": {"valve": {"rec": 3.2}}},
			"charge": {"anim": "thrust", "wu": 0.7, "rec": 0.9, "dmg": 26, "post": 30, "reach": 3.0, "r": [4, 9], "w": 2, "hyper": true, "lunge": 10.0},
			"rivet": {"anim": "shoot", "kind": "shot", "wu": 0.55, "rec": 0.25, "dmg": 9, "post": 6, "r": [5, 40], "w": 3, "snd": "shot_air", "rivet": true, "next": ["rivet", 0.7]},
			"wall": {"anim": "card", "kind": "fn", "fn": "plates", "wu": 0.7, "rec": 0.4, "r": [0, 99], "w": 2, "needs": "box", "part": "box"},
		},
		"lines": {
			"intro": ["你遲到十一分鐘。", "沒關係，工期我有抓餘裕。開始。"],
			"hit": ["這一下不合格。重來。", "動線錯了。你不該站那裡。", "進度落後。"],
			"parried": ["……記錄一下。"],
			"disarmed": ["那是公物。"],
			"kill": ["驗收不通過。拖出去，場地復原。"], "kill3": ["同一個缺失出現四次，這是態度問題。", "我會寫進報告。"],
			"defeat": ["……結構沒有問題。", "是我估錯荷重。", "第六閘的梯子第三階是鬆的。跟你講一聲，那個我一直沒空修。"],
			"laba_intro": "第五閘！監工！她說你遲到。她每個人都說遲到。一賠四！",
			"laba_kill": ["驗收不過。下一位。", "她又在寫報告了。", "第{n}次。三號井，她說你是態度問題。"],
			"laba_win": "過了！驗收過了！四十年第一個！賠四——欸不要推！",
		}},
	"zha": {"name": "閘主", "title": "", "voice": "zha", "bars": [450.0, 480.0, 510.0], "posture": 210.0, "speed": 3.6, "block": 0.5, "dodge": 0.25, "pref": 3.0,
		"melee": "pipewrench", "gun": "qikong", "arena": "cistern", "odds": 20,
		"rig": {"h": 1.82, "bulk": 1.0, "skin": Color(0.62, 0.5, 0.42), "cloth": Color(0.22, 0.24, 0.26), "acc": "coat"},
		"parts": {"screw": "螺輪", "seventh": "第七膛", "wheel": "搖把"},
		"drops": {"gun": "qikong"},
		"moves": {
			"wr1": {"anim": "swing_r", "wu": 0.5, "rec": 0.5, "dmg": 24, "post": 24, "reach": 3.1, "r": [0, 3.4], "w": 3, "next": ["wr2", 0.7]},
			"wr2": {"anim": "swing_l", "wu": 0.4, "rec": 0.5, "dmg": 22, "post": 22, "reach": 3.1, "r": [0, 3.4], "w": 0, "next": ["wr3", 0.6]},
			"wr3": {"anim": "overhead", "wu": 0.7, "rec": 0.8, "dmg": 34, "post": 34, "reach": 3.2, "arc": 70, "r": [0, 3.4], "w": 1, "feint": 0.45},
			"poke": {"anim": "thrust", "wu": 0.38, "rec": 0.5, "dmg": 18, "post": 16, "reach": 3.2, "r": [0, 3.6], "w": 2, "lunge": 5.0},
			"fan": {"anim": "shoot", "kind": "shot", "wu": 0.5, "rec": 0.2, "dmg": 18, "post": 8, "r": [4, 40], "w": 3, "snd": "shot_revolver", "ammo": 1, "next": ["fan", 0.66]},
			"seventh": {"anim": "shoot", "kind": "shot", "wu": 1.0, "rec": 0.9, "dmg": 46, "post": 30, "unb": true, "r": [0, 60], "w": 0, "needs": "seventh", "part": "seventh", "snd": "shot_rifle"},
			"grab": {"anim": "grab", "kind": "fn", "fn": "disarm", "wu": 0.55, "rec": 0.8, "reach": 2.4, "unb": true, "r": [0, 2.6], "w": 2, "needs": "screw", "part": "screw"},
			"reload": {"anim": "reload", "kind": "fn", "fn": "reload", "wu": 1.3, "rec": 0.2, "r": [0, 99], "w": 0, "weak": true},
			"wheel": {"anim": "card", "kind": "fn", "fn": "wheel", "wu": 2.0, "rec": 0.5, "r": [0, 99], "w": 0, "part": "wheel"},
		},
		"lines": {
			"intro": ["坐。先喝一口。這口不算你的。", "庫裡還剩多少，你想知道嗎。", "不想也好。我當年也沒問。"],
			"hit": ["你這把誰改的？扳機行程留太長了。", "重心太前面。", "手腕。"],
			"parried": ["對。就是抓那個時間。"],
			"disarmed": ["對。就是抓那個時間。", "……你師傅教的。"],
			"disarm_you": ["我拆給你看。", "這顆沒鎖緊。"],
			"kill": ["回去吧。跟井邊的人講，下一季別派人來了。"], "kill3": ["還來。……好。水壺拿來，我幫你裝滿。", "坐一下再打。不趕。"],
			"defeat": ["鑰匙在左邊口袋。", "閘輪很緊，要兩隻手。", "底下的水，開一次全閘就沒了。開一道，夠一個井喝一季。我每一季都只開一道。", "你自己看著辦。我不看了。"],
			"laba_intro": "", "laba_kill": ["……", "……"], "laba_win": "",
		}},
}
const PC_LINES = {"bao": "", "xue": "", "ruan": "", "final": "……兩隻手。"}

# 筆記本草圖。cmd: man(x,y,pose) / x / o / arrow / word / obj
const PAGES = {
	"bao_over": {"boss": "bao", "move": "over", "sk": [["man", 0.3, 0.6, "raise"], ["x", 0.36, 0.3], ["man", 0.7, 0.6, "stand"], ["arrow", 0.7, 0.85, 0.2, 0.9], ["word", 0.75, 0.25, "別擋"]]},
	"bao_double": {"boss": "bao", "move": "double", "sk": [["man", 0.3, 0.6, "shoot"], ["obj", "part", 0.45, 0.42], ["o", 0.45, 0.42], ["man", 0.75, 0.6, "reach"], ["arrow", 0.68, 0.48, 0.5, 0.43]]},
	"xue_reload": {"boss": "xue", "move": "shot", "sk": [["man", 0.2, 0.6, "shoot"], ["man", 0.45, 0.6, "slide"], ["man", 0.7, 0.6, "slide"], ["o", 0.7, 0.6], ["arrow", 0.25, 0.9, 0.65, 0.9], ["word", 0.75, 0.2, "等"]]},
	"xue_fly": {"boss": "xue", "move": "knife", "sk": [["man", 0.3, 0.35, "hang"], ["obj", "part", 0.36, 0.2], ["o", 0.36, 0.2], ["man", 0.7, 0.65, "reach"]]},
	"ruan_hive": {"boss": "ruan", "move": "hive", "sk": [["obj", "hive", 0.3, 0.6], ["x", 0.3, 0.6], ["man", 0.7, 0.6, "swing"], ["arrow", 0.62, 0.55, 0.4, 0.58], ["word", 0.7, 0.2, "打得破"]]},
	"ruan_delay": {"boss": "ruan", "move": "delay", "sk": [["man", 0.25, 0.6, "raise"], ["man", 0.5, 0.6, "raise"], ["man", 0.75, 0.6, "raise"], ["o", 0.75, 0.6], ["word", 0.5, 0.2, "慢半拍"]]},
	"yaling_lob": {"boss": "yaling", "move": "lob", "sk": [["obj", "bomb", 0.5, 0.75], ["man", 0.7, 0.6, "swing"], ["arrow", 0.6, 0.7, 0.2, 0.5], ["man", 0.15, 0.6, "stand"], ["word", 0.6, 0.2, "打回去"]]},
	"yaling_det": {"boss": "yaling", "move": "mine", "sk": [["man", 0.3, 0.6, "card"], ["obj", "part", 0.4, 0.5], ["o", 0.4, 0.5], ["man", 0.7, 0.6, "reach"]]},
	"ge_pound": {"boss": "ge", "move": "pound", "sk": [["man", 0.3, 0.6, "raise"], ["obj", "part", 0.24, 0.45], ["o", 0.24, 0.45], ["x", 0.5, 0.85], ["man", 0.75, 0.6, "reach"], ["word", 0.7, 0.2, "瓶"]]},
	"ge_wall": {"boss": "ge", "move": "rivet", "sk": [["man", 0.2, 0.6, "shoot"], ["obj", "wall", 0.5, 0.6], ["man", 0.75, 0.6, "stand"], ["o", 0.75, 0.6]]},
	"zha_grab": {"boss": "zha", "move": "grab", "sk": [["man", 0.3, 0.6, "reach"], ["x", 0.42, 0.45], ["man", 0.7, 0.6, "slide"], ["arrow", 0.6, 0.9, 0.9, 0.9], ["word", 0.5, 0.2, "退"]]},
	"zha_seven": {"boss": "zha", "move": "seventh", "sk": [["man", 0.3, 0.6, "shoot"], ["word", 0.3, 0.2, "七"], ["obj", "part", 0.42, 0.42], ["o", 0.42, 0.42], ["man", 0.75, 0.6, "reach"]]},
	"adv_combo": {"boss": "", "move": "", "sk": [["man", 0.2, 0.6, "swing"], ["arrow", 0.3, 0.9, 0.6, 0.9], ["man", 0.7, 0.6, "shoot"], ["word", 0.45, 0.2, "接"]]},
	"adv_broken": {"boss": "", "move": "", "sk": [["man", 0.3, 0.7, "kneel"], ["o", 0.3, 0.7], ["man", 0.7, 0.6, "shoot"], ["arrow", 0.62, 0.48, 0.38, 0.6]]},
}

# 房間碼符號
const SYMS = ["齒輪", "水滴", "扳手", "螺帽", "火", "錘", "彈", "刀", "蜂", "雷", "閘", "井", "鹽", "鐵", "骨", "煙"]

func melee_parts() -> Dictionary: return MELEE_PARTS
func gun_parts() -> Dictionary: return GUN_PARTS

func part(kind: String, slot: String, id: String) -> Dictionary:
	var tbl = GUN_PARTS if kind == "gun" else MELEE_PARTS
	for p in tbl[slot]:
		if p["id"] == id: return p
	return tbl[slot][0]

# 合成武器數值。mods: {slot: part_id}；off: 被卸掉的 slot 陣列
func wstats(id: String, mods: Dictionary = {}, off: Array = [], quality: float = 1.0) -> Dictionary:
	var kind = wkind(id)
	var base: Dictionary
	if kind == "gun": base = GUNS.get(id, GUNS["liukong"]).duplicate()
	elif kind == "melee": base = MELEE.get(id, MELEE["laoban"]).duplicate()
	else: return GADGETS.get(id, {}).duplicate()
	base["id"] = id; base["kind"] = kind
	if kind == "gun":
		base["relbad"] = 1.0; base["flash"] = 1.0; base["aim"] = 1.0; base["tunnel"] = 1.0
	for slot in mods:
		if off.has(slot): continue
		var p = part(kind, slot, mods[slot])
		for k in p.get("m", {}):
			if base.has(k): base[k] = float(base[k]) * float(p["m"][k])
	if kind == "gun":
		base["mag"] = max(1, int(round(float(base["mag"])))); base["reserve"] = int(round(float(base["reserve"])))
		base["jam"] = clamp((float(base["relbad"]) - 1.0) * 0.012, 0.0, 0.08)
	else:
		base["dmg"] = float(base["dmg"]) * quality
	return base

func wkind(id: String) -> String:
	if GUNS.has(id) or id == "qikong": return "gun"
	if GADGETS.has(id): return "gadget"
	return "melee"

func wname(id: String) -> String:
	if MELEE.has(id): return MELEE[id]["name"]
	if GUNS.has(id): return GUNS[id]["name"]
	if GADGETS.has(id): return GADGETS[id]["name"]
	if CORES.has(id): return CORES[id]["name"]
	return {"knife": "拆信刀", "pipewrench": "管鉗", "qikong": "七孔"}.get(id, id)
