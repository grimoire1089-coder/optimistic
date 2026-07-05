extends Resource
class_name BgmPlaylistRegistry

@export var default_playlist: BgmPlaylistData
@export var location_ids: PackedStringArray = PackedStringArray()
@export var playlists: Array[BgmPlaylistData] = []


func get_playlist_for_location(location_id: StringName) -> BgmPlaylistData:
	var target_id := String(location_id)
	var count := mini(location_ids.size(), playlists.size())
	for i in count:
		if String(location_ids[i]) == target_id:
			var playlist := playlists[i]
			if playlist != null:
				return playlist
	return default_playlist


func has_location(location_id: StringName) -> bool:
	var target_id := String(location_id)
	for id in location_ids:
		if String(id) == target_id:
			return true
	return false
