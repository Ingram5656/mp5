extends RefCounted
## Model (data) — MP5 achievement definitions (v0.5.0). Generated from the same table as design/成就列表.xlsx —
## keep the two in sync. Icons: res://assets/achievements/<icon>.png; while missing, a 🦷 placeholder is drawn.

const GAME_ROCKING := "rocking"

const GROUPS := [
	{"id": "intern", "zh": "实习生", "en": "Intern"},
	{"id": "trainee", "zh": "见习医生", "en": "Trainee Dentist"},
	{"id": "master", "zh": "大师牙医", "en": "Master Dentist"},
	{"id": "skill", "zh": "技术", "en": "Technique"},
	{"id": "total", "zh": "累计", "en": "Milestones"},
	{"id": "fun", "zh": "趣味", "en": "Just for fun"},
]

const LIST := [
	{"id": "rock_first_carrot", "game": GAME_ROCKING, "group": "intern", "hidden": false, "target": 0, "icon": "rock_first_carrot",
		"name": {"zh": "第一根萝卜", "en": "First Carrot"},
		"cond": {"zh": "第一次拔出萝卜（任意难度）", "en": "Pull out a carrot for the first time (any difficulty)"},
		"flavor": {"zh": "哇，真的出来了！", "en": "Whoa, it actually came out!"}},
	{"id": "rock_intern_graduate", "game": GAME_ROCKING, "group": "intern", "hidden": false, "target": 0, "icon": "rock_intern_graduate",
		"name": {"zh": "实习生毕业", "en": "Intern Graduate"},
		"cond": {"zh": "实习生难度下零失误过关", "en": "Clear Intern with no mistakes"},
		"flavor": {"zh": "手稳，可以转正了", "en": "Steady hands. You're hired."}},
	{"id": "rock_slow_steady", "game": GAME_ROCKING, "group": "intern", "hidden": false, "target": 0, "icon": "rock_slow_steady",
		"name": {"zh": "慢工出细活", "en": "Slow and Steady"},
		"cond": {"zh": "实习生难度用时超过 2 分钟仍然过关", "en": "Clear Intern after taking more than 2 minutes"},
		"flavor": {"zh": "你是在给我做按摩吗", "en": "Is this a massage?"}},
	{"id": "rock_trainee_pass", "game": GAME_ROCKING, "group": "trainee", "hidden": false, "target": 0, "icon": "rock_trainee_pass",
		"name": {"zh": "见习合格", "en": "Trainee Certified"},
		"cond": {"zh": "见习医生难度过关", "en": "Clear Trainee Dentist"},
		"flavor": {"zh": "带教老师点了点头", "en": "Your supervisor nods."}},
	{"id": "rock_quick_hands", "game": GAME_ROCKING, "group": "trainee", "hidden": false, "target": 0, "icon": "rock_quick_hands",
		"name": {"zh": "快手", "en": "Quick Hands"},
		"cond": {"zh": "见习医生难度 45 秒内过关", "en": "Clear Trainee Dentist within 45 seconds"},
		"flavor": {"zh": "兔子还没反应过来", "en": "The bunny didn't even see it coming."}},
	{"id": "rock_close_call", "game": GAME_ROCKING, "group": "trainee", "hidden": false, "target": 0, "icon": "rock_close_call",
		"name": {"zh": "惊险过关", "en": "Close Call"},
		"cond": {"zh": "见习医生难度失误刚好用满 3 次，仍然过关", "en": "Clear Trainee Dentist with exactly 3 mistakes (all you were allowed)"},
		"flavor": {"zh": "萝卜差点就没了", "en": "Carrot: That was way too close."}},
	{"id": "rock_carrot_master", "game": GAME_ROCKING, "group": "master", "hidden": false, "target": 0, "icon": "rock_carrot_master",
		"name": {"zh": "拔萝卜高手", "en": "Carrot Master"},
		"cond": {"zh": "大师难度过关", "en": "Clear Master Dentist"},
		"flavor": {"zh": "不看提示也能拔", "en": "No hints needed."}},
	{"id": "rock_practice_perfect", "game": GAME_ROCKING, "group": "master", "hidden": false, "target": 5, "icon": "rock_practice_perfect",
		"name": {"zh": "熟能生巧", "en": "Practice Makes Perfect"},
		"cond": {"zh": "大师难度连续 5 次过关", "en": "Clear Master Dentist 5 times in a row"},
		"flavor": {"zh": "闭着眼都能摇", "en": "Could do this with your eyes closed."}},
	{"id": "rock_lightning", "game": GAME_ROCKING, "group": "master", "hidden": false, "target": 0, "icon": "rock_lightning",
		"name": {"zh": "闪电拔萝卜", "en": "Lightning Pull"},
		"cond": {"zh": "大师难度 40 秒内过关", "en": "Clear Master Dentist within 40 seconds"},
		"flavor": {"zh": "兔子：刚才发生了什么？", "en": "Bunny: Wait, what just happened?"}},
	{"id": "rock_one_shot", "game": GAME_ROCKING, "group": "skill", "hidden": false, "target": 0, "icon": "rock_one_shot",
		"name": {"zh": "一次到位", "en": "Right First Time"},
		"cond": {"zh": "过关，并且这一局每次推进绿区都一次保持成功，没有中途掉出去重来", "en": "Clear a round where every hold in the green zone succeeded first time"},
		"flavor": {"zh": "每一下都刚刚好", "en": "Every push, just right."}},
	{"id": "rock_gentle", "game": GAME_ROCKING, "group": "skill", "hidden": false, "target": 0, "icon": "rock_gentle",
		"name": {"zh": "温柔以待", "en": "Gentle Touch"},
		"cond": {"zh": "过关，并且这一局力矩从没超过绿区上沿", "en": "Clear a round without ever going above the green zone"},
		"flavor": {"zh": "萝卜感觉被温柔对待了", "en": "The carrot feels well cared for."}},
	{"id": "rock_all_rounder", "game": GAME_ROCKING, "group": "skill", "hidden": false, "target": 3, "icon": "rock_all_rounder",
		"name": {"zh": "全能牙医", "en": "All-Round Dentist"},
		"cond": {"zh": "三个难度都至少过关一次", "en": "Clear every difficulty at least once"},
		"flavor": {"zh": "三张证书挂墙上", "en": "Three certificates on the wall."}},
	{"id": "rock_bunny_friend", "game": GAME_ROCKING, "group": "total", "hidden": false, "target": 10, "icon": "rock_bunny_friend",
		"name": {"zh": "兔子的好朋友", "en": "Bunny's Best Friend"},
		"cond": {"zh": "累计拔出 10 根萝卜", "en": "Pull out 10 carrots in total"},
		"flavor": {"zh": "兔子开始等你下班了", "en": "The bunny now waits for you after work."}},
	{"id": "rock_farm_owner", "game": GAME_ROCKING, "group": "total", "hidden": false, "target": 50, "icon": "rock_farm_owner",
		"name": {"zh": "萝卜农场主", "en": "Carrot Farmer"},
		"cond": {"zh": "累计拔出 50 根萝卜", "en": "Pull out 50 carrots in total"},
		"flavor": {"zh": "菜地快被你拔空了", "en": "The field is almost empty."}},
	{"id": "rock_cracked", "game": GAME_ROCKING, "group": "fun", "hidden": true, "target": 0, "icon": "rock_cracked",
		"name": {"zh": "我裂开了", "en": "I'm Cracking Up"},
		"cond": {"zh": "第一次把萝卜弄断", "en": "Snap a carrot for the first time"},
		"flavor": {"zh": "萝卜：……", "en": "Carrot: …"}},
	{"id": "rock_shh", "game": GAME_ROCKING, "group": "fun", "hidden": true, "target": 0, "icon": "rock_shh",
		"name": {"zh": "你小声点", "en": "Inside Voice, Please"},
		"cond": {"zh": "一局里让兔子捂了 3 次耳朵（偏轴提醒）", "en": "Make the bunny cover its ears 3 times in one round (off-axis warnings)"},
		"flavor": {"zh": "兔子：耳朵要聋了", "en": "Bunny: My ears!"}},
	{"id": "rock_wrong_side", "game": GAME_ROCKING, "group": "fun", "hidden": true, "target": 0, "icon": "rock_wrong_side",
		"name": {"zh": "左右不分", "en": "Other Left"},
		"cond": {"zh": "一局里在同一侧连续推了 5 次", "en": "Push the same side 5 times in a row in one round"},
		"flavor": {"zh": "兔子：另一边！另一边！", "en": "Bunny: The other side! The OTHER side!"}},
	{"id": "rock_so_close", "game": GAME_ROCKING, "group": "fun", "hidden": true, "target": 0, "icon": "rock_so_close",
		"name": {"zh": "差一点点", "en": "So Close"},
		"cond": {"zh": "时间到失败，但已经摇了 5 次以上", "en": "Run out of time after 5 or more rocks"},
		"flavor": {"zh": "只差最后一下", "en": "Just one more rock."}},
	{"id": "rock_never_give_up", "game": GAME_ROCKING, "group": "fun", "hidden": true, "target": 0, "icon": "rock_never_give_up",
		"name": {"zh": "越挫越勇", "en": "Never Give Up"},
		"cond": {"zh": "连续失败 3 次后，下一局过关", "en": "Clear a round right after failing 3 in a row"},
		"flavor": {"zh": "萝卜终于服了", "en": "The carrot finally gives in."}},
	{"id": "rock_night_owl", "game": GAME_ROCKING, "group": "fun", "hidden": true, "target": 0, "icon": "rock_night_owl",
		"name": {"zh": "夜猫子", "en": "Night Owl"},
		"cond": {"zh": "在凌晨 0 点到 5 点之间过关", "en": "Clear a round between midnight and 5 a.m."},
		"flavor": {"zh": "兔子都睡了，你还在练", "en": "The bunny's asleep. You're still practising."}},
]


static func get_def(id: String) -> Dictionary:
	for d in LIST:
		if d["id"] == id:
			return d
	return {}


static func text(d: Dictionary, field: String, lang: String) -> String:
	var t: Dictionary = d[field]
	return t.get(lang, t["en"])
