extends RefCounted
## Model (persistence) — writes an evaluation report to a folder the user chose (v0.5.4; moved out of
## report_view.gd; v0.6.0: either game). Files: <base>.png (picture of the report, supplied by the view), <base>_scores.csv,
## <base>_samples.csv (samples with the standard curve alongside).

const Evaluation := preload("res://app_v0.8.1/scripts/models/evaluation.gd")


## Returns the base path ("" on failure).
static func save_report(dir: String, data: Dictionary, rep: Dictionary, picture: Image) -> String:
	var stamp := str(data.get("at", Time.get_datetime_string_from_system())).replace(":", "").replace("-", "").replace(" ", "_").replace("T", "_")
	var kind := "balloon" if str(data.get("game", "")) == "balloon" else "carrot"
	var base := dir.path_join("MP5_%s_report_%s" % [kind, stamp])
	var ok := true
	if picture != null:
		ok = picture.save_png(base + ".png") == OK
	var f := FileAccess.open(base + "_scores.csv", FileAccess.WRITE)
	if f != null:
		f.store_line("item,value")
		f.store_line("date,%s" % str(data.get("at", "")))
		f.store_line("difficulty,%d" % int(data.get("difficulty", 1)))
		f.store_line("result,%s" % str(data.get("result", "")))
		f.store_line("grade,%s" % str(rep["grade"]))
		f.store_line("total,%.1f" % float(rep["total"]))
		var order: Array = rep.get("order", Evaluation.ORDER)
		var weights: Dictionary = rep.get("weights", Evaluation.WEIGHTS)
		f.store_line("game,%s" % kind)
		for k in order:
			var v = rep["dims"][k]
			f.store_line("%s_score,%s" % [k, "n/a" if v == null else "%.1f" % float(v)])
			f.store_line("%s_weight,%d" % [k, int(weights[k])])
		var mt: Dictionary = rep["metrics"]
		for k in mt.keys():
			f.store_line("%s,%s" % [k, str(snappedf(float(mt[k]), 0.0001))])
		f.close()
	else:
		ok = false
	var g := FileAccess.open(base + "_samples.csv", FileAccess.WRITE)
	if g != null:
		g.store_line("t_s,moment_nm,standard_nm,offaxis_nm,pull_n")
		var t: PackedFloat32Array = data["t"]
		var m: PackedFloat32Array = data["m"]
		var off: PackedFloat32Array = data["off"]
		var pull: PackedFloat32Array = data["pull"]
		var std: PackedFloat32Array = rep["standard"]
		for i in t.size():
			g.store_line("%.3f,%.4f,%.4f,%.4f,%.3f" % [t[i], m[i], std[i], off[i], pull[i]])
		g.close()
	else:
		ok = false
	return base if ok else ""
