class_name RunState
extends RefCounted
## The run loop's memory (spec run: lives 1, best_score_persisted). Plain
## RefCounted so the battery can drive it with a throwaway save path.
##
## The save is three lines at Feel.BEST_SCORE_SAVE_PATH:
##   best / runs_finished / muted
## "RUN N" is derived: next_run_number() = runs_finished + 1. A missing or
## corrupt file is a fresh garden, never an error (first web boot has nothing).

var best := 0
var runs_finished := 0
var muted := false
var save_path := Feel.BEST_SCORE_SAVE_PATH


func load_state() -> void:
	best = 0
	runs_finished = 0
	muted = false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	best = maxi(f.get_line().to_int(), 0)
	runs_finished = maxi(f.get_line().to_int(), 0)
	muted = f.get_line().to_int() == 1


func save_state() -> bool:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("%d\n%d\n%d\n" % [best, runs_finished, 1 if muted else 0])
	return true


## The "RUN N" stamp for the HUD/title: the run about to be played.
func next_run_number() -> int:
	return runs_finished + 1


## Death bookkeeping: best never goes down, the counter ticks, and the state
## persists so the retry (a fresh scene) picks up where the garden left off.
func finish_run(score: int) -> int:
	best = maxi(best, score)
	runs_finished += 1
	save_state()
	return best


## Mute toggle, persisted with the run state.
func set_muted(value: bool) -> bool:
	muted = value
	return save_state()
