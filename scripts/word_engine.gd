class_name WordEngine
extends RefCounted
## The word side of the Old Bargain (LORE.md): the round shows a TARGET WORD,
## bugs carry letters, and eating them in the order the Word asks pays out.
##
## Pure and scene-free so the battery can drive it directly: a seeded
## RandomNumberGenerator in, deterministic words/letters/score out.
##
## Laws implemented here (spec spelling + score):
##   - words come from data/word_list.txt, 3-5 letters only
##   - letters_spawn_bias: a respawned bug carries the NEXT needed letter with
##     60% probability, else a uniform random A-Z (roll_spawn_letter)
##   - gold bugs are any-letter wildcards consumed in order (WILDCARD letter)
##   - every bug is worth base points; completing the word pays
##     WORD_COMPLETE_BONUS x chain_mult, then chain_mult steps up

const WILDCARD := "?"                 # Feel.WILDCARD_GLYPH, duplicated as a
                                      # const so the engine stays RefCounted-pure
enum EatResult { WRONG, ADVANCED, COMPLETED }

var words := PackedStringArray()      # length-filtered play words
var total_lines := 0                  # every line in the file (test sanity)
var target := ""
var progress := 0                     # letters filled so far
var score := 0
var bugs_eaten := 0
var words_completed := 0
var chain_mult := 1.0
var rng := RandomNumberGenerator.new()

var _last_word := ""                  # never deal the same word twice running


func _init(list_path := Feel.WORD_LIST_PATH) -> void:
	load_words(list_path)


# ------------------------------------------------------------------- loading --

## Read the word file, keep A-Z words in the play-length band. Returns the
## number of playable words (0 also means the file was missing/unreadable).
func load_words(path: String) -> int:
	words = PackedStringArray()
	total_lines = 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		total_lines += 1
		if line.length() < Feel.WORD_LEN_MIN or line.length() > Feel.WORD_LEN_MAX:
			continue
		if not is_word_shape(line):
			continue
		words.append(line)
	return words.size()


static func is_word_shape(w: String) -> bool:
	for i in w.length():
		var c := w.unicode_at(i)
		if c < 65 or c > 90:  # A-Z only — the list is uppercase SCOWL common
			return false
	return true


static func random_letter(r: RandomNumberGenerator) -> String:
	return char(65 + r.randi_range(0, 25))


# --------------------------------------------------------------------- words --

## Deal a new target word (never the same one twice running) and reset the
## fill state. Chain multiplier and score survive the swap.
func new_word() -> String:
	if words.is_empty():
		target = ""
		progress = 0
		return ""
	var pick := _last_word
	for guard in 8:
		pick = words[rng.randi_range(0, words.size() - 1)]
		if pick != _last_word:
			break
	_last_word = pick
	target = pick
	progress = 0
	return target


## The letter the Word needs next, or "" when the word is already complete.
func next_letter() -> String:
	if target.is_empty() or progress >= target.length():
		return ""
	return target[progress]


func is_needed(letter: String) -> bool:
	return letter == next_letter()


## Word display state for the HUD: filled letters, then underscores.
func word_display() -> String:
	var out := ""
	for i in target.length():
		out += target[i] if i < progress else Feel.HUD_SLOT_EMPTY_GLYPH
	return out


# -------------------------------------------------------------- spawn bias ----

## The respawn law: with WORD_LETTER_SPAWN_BIAS probability the bug carries the
## next needed letter of the target word, else a uniform random A-Z. With no
## word in play it degenerates to uniform random.
func roll_spawn_letter(r: RandomNumberGenerator) -> String:
	if not target.is_empty() and r.randf() < Feel.WORD_LETTER_SPAWN_BIAS:
		return next_letter()
	return random_letter(r)


# -------------------------------------------------------------------- eating --

## Consume a bug's letter. Every bug pays its base points; a letter that
## matches the next needed slot (or any gold wildcard) advances the word, and
## the last letter pays WORD_COMPLETE_BONUS x chain_mult, steps the chain, and
## deals the next word. Returns { "result": EatResult, "points": int }.
func eat(letter: String, gold := false) -> Dictionary:
	bugs_eaten += 1
	var points := Feel.SCORE_GOLD_BUG if gold else Feel.SCORE_PER_BUG
	score += points
	var result: int = EatResult.WRONG
	if not target.is_empty() and progress < target.length() \
			and (gold or letter == target[progress]):
		progress += 1
		if progress >= target.length():
			result = EatResult.COMPLETED
			score += int(Feel.WORD_COMPLETE_BONUS * chain_mult)
			words_completed += 1
			chain_mult += Feel.CHAIN_MULT_STEP
			new_word()
		else:
			result = EatResult.ADVANCED
	return {"result": result, "points": points}


## Convenience for HUD/tests: did that last eat complete a word?
static func is_complete(result: Dictionary) -> bool:
	return result.get("result", EatResult.WRONG) == EatResult.COMPLETED
