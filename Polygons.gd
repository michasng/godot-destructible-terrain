class_name Polygons

static func resolve_holes(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	"""
	Resolves holes in an array of polygons.
	"""
	# nothing to do
	if not has_hole(polygons):
		return polygons
	
	var results: Array[PackedVector2Array] = []
	var grouped_polygons = _group_for_holes(polygons)
	for polygon_group in grouped_polygons:
		var polygon: PackedVector2Array = polygon_group["outer"]
		for inner_polygon: PackedVector2Array in polygon_group["inners"]:
			# rely on the fact that inners are sorted by distance, to prevent crossing edges
			polygon = resolve_hole(polygon, inner_polygon)
		results.append(polygon)
	return results


# Use Array parameter type, because it exports some functions used here 
static func resolve_hole(outer: PackedVector2Array, inner: PackedVector2Array) -> PackedVector2Array:
	"""
	Combines an outer polygon with an inner (hole) polygon
	by adding an edge between them.
	Referece: https://en.wikipedia.org/wiki/Polygon_with_holes
	
	Will not modify the input values.
	"""
	assert(Geometry2D.is_polygon_clockwise(inner))
	assert(not Geometry2D.is_polygon_clockwise(outer))
	
	# the edge should connect the polygons at their shortest distance
	# to avoid cutting through the inner polygon
	# or through concave parts of the outer polygon
	var edge_indexes := _find_closest_points(outer, inner)
	
	# offset all array indices, so the edge_index is the first element
	var result := _shift_array(outer, edge_indexes[0])
	
	# ensure the edge has a starting position
	if result.back() != result.front():
		result.append(result.front())
		
	# offset all array indices, so the edge_index is the first element
	# so the end of the edge is at the start
	var shifted_inner := _shift_array(inner, edge_indexes[1])
	
	# utilize the fact that the inner polygon is already clockwise
	result.append_array(shifted_inner)

	# make sure to add another edge back to the start
	if shifted_inner.back() != shifted_inner.front():
		result.append(shifted_inner.front())
	
	return PackedVector2Array(result)


static func _find_closest_points(polygon1: PackedVector2Array, polygon2: PackedVector2Array) -> Array[int]:
	"""
	Finds the closest points between two polygons returns their indexes.
	"""
	var minimal_distance := INF
	var minimal_distance_indexes: Array[int]
	for i in range(polygon1.size()):
		for j in range(polygon2.size()):
			var distance := polygon1[i].distance_squared_to(polygon2[j])
			if distance < minimal_distance:
				minimal_distance = distance
				minimal_distance_indexes = [i, j]
	return minimal_distance_indexes


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


static func clip(polygon: PackedVector2Array, clipping_polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	"""
	Clips a polygon and resolves any inner (hole) polygons.
	"""
	var clipped := Geometry2D.clip_polygons(polygon, clipping_polygon)
	return resolve_holes(clipped)


static func merge(polygons_to_merge: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	"""
	Returns a list of merged polygons without holes.
	"""
	# nothing to merge for 0 or 1 item(s)
	if len(polygons_to_merge) < 2:
		return polygons_to_merge

	# current results
	var polygons: Array[PackedVector2Array] = polygons_to_merge.duplicate()
	# temporary list for all polygons that have not been merged yet
	var unmerged_polygons: Array[PackedVector2Array] = polygons.duplicate()
	while not unmerged_polygons.is_empty():
		# loop backwards, so the arrays can be modified during iteration
		for i in range(unmerged_polygons.size()-1, -1, -1):
			var unmerged_polygon := unmerged_polygons[i]
			unmerged_polygons.remove_at(i)
			for j in range(polygons.size()-1, -1, -1):
				var polygon := polygons[j]
				if unmerged_polygon == polygon:
					continue
				
				var merged1 := Geometry2D.merge_polygons(unmerged_polygon, polygon)
				var merged := resolve_holes(merged1)
				# assert(not has_hole(merged)) <-- this sometimes fails
				
				match merged.size():
					0:
						# these two resolve each other completely
						# go on to the next unmerged_polygon
						break
					1:
						# merge successful
						polygons.remove_at(j)
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


static func has_hole(polygons: Array[PackedVector2Array]) -> bool:
	"""
	Returns whether there are any holes in polygons.
	"""
	for polygon in polygons:
		if Geometry2D.is_polygon_clockwise(polygon):
			return true
	return false


class DistanceKeySorter:
	static func sort_ascending(a, b):
		if a["distance"] < b["distance"]:
			return true
		return false


static func _group_for_holes(polygons: Array[PackedVector2Array]) -> Array[Dictionary]:
	"""
	Returns an Array of a Dictionaries for each polygon (with or without holes).
	Each Dictionary contains one `outer` polygon
	and an array of `inners` (hole) polygons, that might be empty.
	Inner polygons are sorted by ascending distance to their outer polygon.
	
	Required, because the return values of the Geometry functions are unsorted.
	"""
	# group polygons
	var outer: Array[PackedVector2Array] = []
	var inners: Array[PackedVector2Array] = []
	for polygon in polygons:
		if Geometry2D.is_polygon_clockwise(polygon):
			inners.append(polygon)
		else:
			outer.append(polygon)
	
	# match inner polygons to their outer counterparts
	var results: Array[Dictionary] = []
	for outer_polygon in outer:
		var inners_of_outer_with_distance = []
		# loop backwards to modify the array during iteration
		for inner_index in range(inners.size()-1, -1, -1):
			var inner_polygon = inners[inner_index]
			# an inner polygon belongs to an outer polygon,
			# if any one of it's points is inside the outer polygon
			if Geometry2D.is_point_in_polygon(inner_polygon[0], outer_polygon):
				# find the connecting edge now, because inner_polygons need to be resolved in order
				var connecting_edge_indexes = _find_closest_points(outer_polygon, inner_polygon)
				var connecting_edge = [outer_polygon[connecting_edge_indexes[0]], inner_polygon[connecting_edge_indexes[1]]]
				inners_of_outer_with_distance.append({
					"inner_polygon": inner_polygon,
					"distance": connecting_edge[0].distance_squared_to(connecting_edge[1]),
				})
				# each inner can only be inside a single outer polygon
				inners.remove_at(inner_index)
		inners_of_outer_with_distance.sort_custom(Callable(DistanceKeySorter, "sort_ascending"))
		var inners_of_outer = []
		for inner_with_distance in inners_of_outer_with_distance:
			inners_of_outer.append(inner_with_distance.inner_polygon)
		results.append({
			"outer": outer_polygon,
			"inners": inners_of_outer,
		})
	return results
