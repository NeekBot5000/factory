class_name Util
extends RefCounted

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


static func fmt(v: float) -> String:
	var a: float = absf(v)
	var i := 0
	while a >= 1000.0 and i < SUFFIXES.size() - 1:
		a /= 1000.0
		i += 1
	var s: String
	if i == 0:
		if a < 10.0 and absf(a - roundf(a)) > 0.001:
			s = "%.2f" % a
		elif a < 100.0 and absf(a - roundf(a)) > 0.001:
			s = "%.1f" % a
		else:
			s = "%d" % int(roundf(a))
	elif a < 10.0:
		s = "%.2f" % a
	elif a < 100.0:
		s = "%.1f" % a
	else:
		s = "%.0f" % a
	return ("-" if v < 0.0 else "") + s + SUFFIXES[i]


static func money(v: float) -> String:
	return "$" + fmt(v)
