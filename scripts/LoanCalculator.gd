extends RefCounted

## Pure parsing, schedule normalization, and interest calculations for state loans.

func extract_numeric_tokens(raw: String) -> Array:
	var text = raw.strip_edges().replace(",", ".")
	if text == "":
		return []
	var regex := RegEx.new()
	if regex.compile("[-+]?[0-9]*\\.?[0-9]+") != OK:
		return []
	var values: Array = []
	for match_result in regex.search_all(text):
		var token = match_result.get_string(0)
		if token != "" and token.is_valid_float():
			values.append(float(token))
	return values

func parse_terms(value_a: String, value_b: String, min_interest: float, max_interest: float, min_turns: int, max_turns: int) -> Dictionary:
	var numbers: Array = extract_numeric_tokens(value_a)
	numbers.append_array(extract_numeric_tokens(value_b))
	if numbers.size() < 3:
		return {"ok": false, "reason": "Loan requires 3 numbers: principal, interest%, turns. Example: '120, 7.5, 10'."}
	var principal = float(numbers[0])
	var interest_pct = float(numbers[1])
	var turns = int(round(float(numbers[2])))
	if principal <= 0.0:
		return {"ok": false, "reason": "Loan principal must be positive."}
	if interest_pct < min_interest or interest_pct > max_interest:
		return {"ok": false, "reason": "Loan interest must be between %.1f%% and %.1f%%." % [min_interest, max_interest]}
	if turns < min_turns or turns > max_turns:
		return {"ok": false, "reason": "Loan duration must be between %d and %d turns." % [min_turns, max_turns]}
	return {"ok": true, "principal": principal, "interest_pct": interest_pct, "turns": turns}

func total_due(principal: float, interest_pct: float) -> float:
	return max(0.0, principal) * (1.0 + max(0.0, interest_pct) / 100.0)

func installment(principal: float, interest_pct: float, turns: int) -> float:
	return total_due(principal, interest_pct) / float(max(1, turns))

func normalize_schedule(loan: Dictionary) -> Dictionary:
	var normalized = loan.duplicate(true)
	var principal = max(0.0, float(normalized.get("principal", 0.0)))
	var interest_pct = max(0.0, float(normalized.get("interest_pct", 0.0)))
	var turns_total = max(1, int(normalized.get("turns_total", max(1, int(normalized.get("remaining_turns", 1))))))
	var remaining_turns = max(0, int(normalized.get("remaining_turns", turns_total)))
	var expected_total = total_due(principal, interest_pct)
	var expected_installment = installment(principal, interest_pct, turns_total)
	var expected_remaining = max(0.0, expected_installment * float(remaining_turns))
	var current_installment = max(0.0, float(normalized.get("installment", expected_installment)))
	var current_remaining = max(0.0, float(normalized.get("remaining_due", expected_remaining)))
	if str(normalized.get("interest_model", "")).strip_edges().to_lower() != "term_total":
		if current_installment > expected_installment * 1.25 or current_remaining > expected_remaining * 1.25:
			normalized["installment"] = expected_installment
			normalized["remaining_due"] = min(current_remaining, max(expected_remaining, expected_total))
		normalized["interest_model"] = "term_total"
	return normalized

func interest_part(loan: Dictionary, paid_this_turn: float) -> float:
	var paid = max(0.0, paid_this_turn)
	if paid <= 0.0:
		return 0.0
	var remaining_turns = max(1, int(loan.get("remaining_turns", 1)))
	var turns_total = max(1, int(loan.get("turns_total", remaining_turns)))
	var principal = max(0.0, float(loan.get("principal", 0.0)))
	var interest_pct = max(0.0, float(loan.get("interest_pct", 0.0)))
	return min(paid, principal * (interest_pct / 100.0) / float(turns_total))
