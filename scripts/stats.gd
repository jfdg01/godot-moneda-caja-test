extends RefCounted
class_name Stats

var _values: Array[float] = []

func add(value: float) -> void:
	_values.append(value)

func count() -> int:
	return _values.size()

func mean() -> float:
	if _values.is_empty(): return 0.0
	var sum := 0.0
	for v in _values:
		sum += v
	return sum / _values.size()

func median() -> float:
	if _values.is_empty(): return 0.0
	var sorted := _values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	if sorted.size() % 2 == 0:
		return (sorted[mid - 1] + sorted[mid]) / 2.0
	return sorted[mid]

func std_dev() -> float:
	if _values.size() < 2: return 0.0
	var m := mean()
	var sum := 0.0
	for v in _values:
		sum += (v - m) * (v - m)
	return sqrt(sum / _values.size())

func min_val() -> float:
	if _values.is_empty(): return 0.0
	return _values.min()

func max_val() -> float:
	if _values.is_empty(): return 0.0
	return _values.max()

# Returns values more than z_threshold standard deviations from the mean
func outliers(z_threshold: float = 2.0) -> Array[float]:
	if _values.size() < 3: return []
	var m := mean()
	var sd := std_dev()
	if sd == 0.0: return []
	var result: Array[float] = []
	for v in _values:
		if abs(v - m) / sd > z_threshold:
			result.append(v)
	return result

func report() -> void:
	print("=== Stats Report (n=%d) ===" % count())
	print("  mean:    %.2f" % mean())
	print("  median:  %.2f" % median())
	print("  std_dev: %.2f" % std_dev())
	print("  min:     %.2f" % min_val())
	print("  max:     %.2f" % max_val())
	print("  outliers (>2σ): ", outliers())
	print("===========================")

func clear() -> void:
	_values.clear()
