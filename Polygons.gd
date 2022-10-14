class_name Polygons

static func resolve_holes(polygons: Array) -> Array:
	"""
	Resolves holes in an array of polygons.
	
	Proof of Concept: Currently only works for single holes in an array of two polygons.
	"""
	if polygons.size() == 2:
		if Geometry.is_polygon_clockwise(polygons[0]):
			return [resolve_hole(polygons[1], polygons[0])]
		elif Geometry.is_polygon_clockwise(polygons[1]):
			return [resolve_hole(polygons[0], polygons[1])]
	return polygons

# Use Array parameter type, because it exports some functions used here 
static func resolve_hole(outer: Array, inner: Array) -> PoolVector2Array:
	"""
	Combines an outer polygon with an inner (hole) polygon
	by adding an edge between them.
	Referece: https://en.wikipedia.org/wiki/Polygon_with_holes
	
	Will not modify the input values.
	"""
	assert(Geometry.is_polygon_clockwise(inner))
	assert(not Geometry.is_polygon_clockwise(outer))
	
	# use the outer polygon as a basis
	var result = outer.duplicate()
	
	# ensure the edge has a starting position
	var edge_start = outer.front()
	if outer.back() != edge_start:
		result.append(edge_start)
	
	# find the ideal connection
	var edge_end_index = _find_closest_point_index(edge_start, inner)
	# offset all array indices, so edge_end_index is the last element
	var shifted_inner = _shift_array(inner, edge_end_index + 1)
	
	# ensure the edge has a ending position
	var edge_end = inner[edge_end_index]
	if shifted_inner.front() != edge_end:
		result.append(edge_end)
	
	# utilize the fact that the inner polygon is already clockwise
	result.append_array(shifted_inner)
	return PoolVector2Array(result)


static func _find_closest_point_index(origin: Vector2, points: Array) -> int:
	"""
	Finds the closest point to `origin` in `points` and returns it's index.
	"""
	var minimal_distance = INF
	var minimal_distance_index = -1
	for index in range(points.size()):
		var distance = origin.distance_squared_to(points[index])
		if distance < minimal_distance:
			minimal_distance = distance
			minimal_distance_index = index
	return minimal_distance_index


static func _shift_array(arr: Array, begin_index: int) -> Array:
	"""
	Moves all items in an array,
	so the item currently at begin_index will be at index 0.

	Returns a new array and leaves the input parameter untouched.
	"""
	# module array size to handle indexes beyond the normal range
	if (begin_index % arr.size()) == 0:
		return arr
	var result = arr.slice(begin_index, arr.size() - 1)
	result.append_array(arr.slice(0, begin_index - 1))
	return result


static func clip(polygon: PoolVector2Array, clipping_polygon: PoolVector2Array) -> Array:
	"""
	Clips a polygon and resolves any inner (hole) polygons.
	"""
	var clipped = Geometry.clip_polygons_2d(polygon, clipping_polygon)
	return resolve_holes(clipped)


static func merge(polygons_to_merge: Array) -> Array:
	"""
	Returns a list of merged polygons without holes.
	This is a heuristic, that may not always merge all polygons in an ideal way.
	"""
	# nothing to merge for 0 or 1 item(s)
	if len(polygons_to_merge) < 2:
		return polygons_to_merge

	# current results
	var polygons = polygons_to_merge.duplicate()
	# temporary list for all polygons that have not been merged yet
	var unmerged_polygons = polygons.duplicate()
	while not unmerged_polygons.empty():
		# loop backwards, so the arrays can be modified during iteration
		for i in range(unmerged_polygons.size() - 1, -1, -1):
			var unmerged_polygon = unmerged_polygons[i]
			unmerged_polygons.remove(i)
			for j in range(polygons.size() - 1, -1, -1):
				var polygon = polygons[j]
				if unmerged_polygon == polygon:
					continue
				
				var merged = Geometry.merge_polygons_2d(unmerged_polygon, polygon)
				merged = resolve_holes(merged)	
				# This doesn't work for multiple holes yet
				# assert(not _is_hole(merged))
				
				match merged.size():
					0:
						# these two resolve each other completely
						# go on to the next unmerged_polygon
						break
					1:
						# merge successful
						polygons.remove(j)
						polygons.erase(unmerged_polygon)
						polygons.append(merged[0])
						# still need to merge the new polygon
						unmerged_polygons.append(merged[0])
						# now do the next unmerged_polygon
						break
					_:
						# these two could not be merged into a single polygon
						# continue as usual
						pass
	return polygons


static func has_hole(polygons) -> bool:
	"""
	Return whether there are any holes in polygons.
	"""
	for polygon in polygons:
		if Geometry.is_polygon_clockwise(polygon):
			return true
	return false

