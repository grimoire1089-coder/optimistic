extends Node
class_name WorkRankRegistry

signal job_rank_changed(job_id: StringName, new_rank: int, previous_rank: int)
signal job_completed(job_id: StringName, completion_count: int, rank: int)

const SAVE_KEY_JOB_RANKS := "work_job_ranks"
const SAVE_KEY_JOB_COMPLETION_COUNTS := "work_job_completion_counts"
const DEFAULT_RANK := 1
const MAX_RANK := 10

var _job_ranks: Dictionary = {}
var _job_completion_counts: Dictionary = {}


func get_job_rank(job_id: StringName) -> int:
	if job_id == &"":
		return DEFAULT_RANK
	var key := _job_key(job_id)
	return clampi(int(_job_ranks.get(key, DEFAULT_RANK)), DEFAULT_RANK, MAX_RANK)


func get_job_completion_count(job_id: StringName) -> int:
	if job_id == &"":
		return 0
	return maxi(int(_job_completion_counts.get(_job_key(job_id), 0)), 0)


func get_max_rank() -> int:
	return MAX_RANK


func record_job_completed(job_id: StringName, rank_gain: int = 1) -> Dictionary:
	if job_id == &"":
		return {}

	var key := _job_key(job_id)
	var previous_rank := get_job_rank(job_id)
	var completion_count := get_job_completion_count(job_id) + 1
	var next_rank := clampi(previous_rank + maxi(rank_gain, 0), DEFAULT_RANK, MAX_RANK)

	_job_completion_counts[key] = completion_count
	_job_ranks[key] = next_rank

	job_completed.emit(job_id, completion_count, next_rank)
	if next_rank != previous_rank:
		job_rank_changed.emit(job_id, next_rank, previous_rank)

	return {
		"previous_rank": previous_rank,
		"rank": next_rank,
		"completion_count": completion_count,
		"rank_changed": next_rank != previous_rank,
	}


func reset_for_new_game() -> void:
	_job_ranks.clear()
	_job_completion_counts.clear()


func to_save_data() -> Dictionary:
	return {
		SAVE_KEY_JOB_RANKS: _job_ranks.duplicate(true),
		SAVE_KEY_JOB_COMPLETION_COUNTS: _job_completion_counts.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> void:
	_job_ranks.clear()
	_job_completion_counts.clear()
	if data.has(SAVE_KEY_JOB_RANKS):
		var raw_ranks_value: Variant = data.get(SAVE_KEY_JOB_RANKS, {})
		if raw_ranks_value is Dictionary:
			var raw_ranks: Dictionary = raw_ranks_value
			for key in raw_ranks.keys():
				_job_ranks[str(key)] = clampi(int(raw_ranks[key]), DEFAULT_RANK, MAX_RANK)
	if data.has(SAVE_KEY_JOB_COMPLETION_COUNTS):
		var raw_counts_value: Variant = data.get(SAVE_KEY_JOB_COMPLETION_COUNTS, {})
		if raw_counts_value is Dictionary:
			var raw_counts: Dictionary = raw_counts_value
			for key in raw_counts.keys():
				_job_completion_counts[str(key)] = maxi(int(raw_counts[key]), 0)


func _job_key(job_id: StringName) -> String:
	return String(job_id)
