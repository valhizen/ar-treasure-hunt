extends Resource
class_name MinigameResult
## MinigameResult - Standardized result from minigames
## All minigames return this when they complete

#region Result Data
## Whether the minigame was completed successfully
@export var success: bool = false

## Score achieved (0 if not applicable)
@export var score: int = 0

## Time taken to complete (seconds)
@export var time_taken: float = 0.0

## Star rating (0-3, optional)
@export var stars: int = 0

## Keys found during this minigame session
@export var keys_found: Array[String] = []

## Items to award player
## Format: [{"id": "item_name", "amount": 1, "special": false}, ...]
@export var items_awarded: Array[Dictionary] = []

## Currency to award
@export var currency_awarded: int = 0

## If failed, why?
@export var failure_reason: String = ""

## Any custom data the minigame wants to pass back
@export var custom_data: Dictionary = {}
#endregion

#region Factory Methods
static func create_success(p_score: int = 0, p_time: float = 0.0) -> MinigameResult:
	"""Create a successful result"""
	var result = MinigameResult.new()
	result.success = true
	result.score = p_score
	result.time_taken = p_time
	return result


static func create_failure(reason: String = "Failed") -> MinigameResult:
	"""Create a failure result"""
	var result = MinigameResult.new()
	result.success = false
	result.failure_reason = reason
	return result
#endregion

#region Builder Pattern Methods (for chaining)
func with_score(p_score: int) -> MinigameResult:
	score = p_score
	return self


func with_time(p_time: float) -> MinigameResult:
	time_taken = p_time
	return self


func with_stars(p_stars: int) -> MinigameResult:
	stars = clampi(p_stars, 0, 3)
	return self


func with_key(key_id: String) -> MinigameResult:
	if key_id not in keys_found:
		keys_found.append(key_id)
	return self


func with_keys(key_ids: Array[String]) -> MinigameResult:
	for key_id in key_ids:
		with_key(key_id)
	return self


func with_item(item_id: String, amount: int = 1, is_special: bool = false) -> MinigameResult:
	items_awarded.append({
		"id": item_id,
		"amount": amount,
		"special": is_special
	})
	return self


func with_currency(amount: int) -> MinigameResult:
	currency_awarded += amount
	return self


func with_custom(key: String, value: Variant) -> MinigameResult:
	custom_data[key] = value
	return self
#endregion

#region Star Calculation Helpers
func calculate_stars_by_score(thresholds: Array[int]) -> MinigameResult:
	"""
	Calculate stars based on score thresholds.
	thresholds = [bronze, silver, gold] e.g., [100, 500, 1000]
	"""
	stars = 0
	for threshold in thresholds:
		if score >= threshold:
			stars += 1
	return self


func calculate_stars_by_time(thresholds: Array[float], lower_is_better: bool = true) -> MinigameResult:
	"""
	Calculate stars based on time thresholds.
	thresholds = [3_star_time, 2_star_time, 1_star_time]
	lower_is_better: if true, faster time = more stars
	"""
	stars = 0
	if lower_is_better:
		# Faster is better: [30, 60, 120] means <30 = 3 stars, <60 = 2 stars, etc.
		for i in range(thresholds.size()):
			if time_taken <= thresholds[i]:
				stars = thresholds.size() - i
				break
	else:
		# Longer is better (survival games)
		for threshold in thresholds:
			if time_taken >= threshold:
				stars += 1
	return self
#endregion

#region Debug
func _to_string() -> String:
	return "MinigameResult(success=%s, score=%d, time=%.2f, stars=%d, keys=%s)" % [
		success, score, time_taken, stars, keys_found
	]
#endregion
