class_name Polygons

static func resolve_holes(polygons: Array) -> Array:
	"""
	Resolves holes in an array of polygons.
	"""
	# nothing to do
	if not has_hole(polygons):
		return polygons
	
	var results = []
	var grouped_polygons = _group_for_holes(polygons)
	for polygon_group in grouped_polygons:
		var polygon = polygon_group["outer"]
		for inner_polygon in polygon_group["inner"]:
			# ToDo: There are still some issues depending on the order of the inner polygons,
			# if e.g. the second inner is on the edge of the first inner to the outer
			polygon = resolve_hole(polygon, inner_polygon)
		results.append(polygon)
	return results


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
	
	# the edge should connect the polygons at their shortest distance
	# to avoid cutting through the inner polygon
	# or through concave parts of the outer polygon
	var edge_indexes = _find_closest_points(outer, inner)
	
	# offset all array indices, so the edge_index is the first element
	var result = _shift_array(outer, edge_indexes[0])
	
	# ensure the edge has a starting position
	if result.back() != result.front():
		result.append(result.front())
		
	# offset all array indices, so the edge_index is the first element
	# so the end of the edge is at the start
	var shifted_inner = _shift_array(inner, edge_indexes[1])
	
	# utilize the fact that the inner polygon is already clockwise
	result.append_array(shifted_inner)

	# make sure to add another edge back to the start
	if shifted_inner.back() != shifted_inner.front():
		result.append(shifted_inner.front())
	
	return PoolVector2Array(result)


static func _find_closest_points(polygon1: PoolVector2Array, polygon2: PoolVector2Array) -> Array:
	"""
	Finds the closest points between two polygons returns their indexes.
	"""
	var minimal_distance = INF
	var minimal_distance_indexes
	for i in range(polygon1.size()):
		for j in range(polygon2.size()):
			var distance = polygon1[i].distance_squared_to(polygon2[j])
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


static func clip(polygon: PoolVector2Array, clipping_polygon: PoolVector2Array) -> Array:
	"""
	Clips a polygon and resolves any inner (hole) polygons.
	"""
	var clipped = Geometry.clip_polygons_2d(polygon, clipping_polygon)
	return resolve_holes(clipped)


static func merge(polygons_to_merge: Array) -> Array:
	"""
	Returns a list of merged polygons without holes.
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
		for i in range(unmerged_polygons.size()-1, -1, -1):
			var unmerged_polygon = unmerged_polygons[i]
			unmerged_polygons.remove(i)
			for j in range(polygons.size()-1, -1, -1):
				var polygon = polygons[j]
				if unmerged_polygon == polygon:
					continue
				
				var merged1 = Geometry.merge_polygons_2d(unmerged_polygon, polygon)
				var merged = resolve_holes(merged1)
				assert(not has_hole(merged))
				
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


static func has_hole(polygons: Array) -> bool:
	"""
	Returns whether there are any holes in polygons.
	"""
	for polygon in polygons:
		if Geometry.is_polygon_clockwise(polygon):
			return true
	return false


static func _group_for_holes(polygons: Array) -> Array:
	"""
	Returns an Array of a Dictionaries for each polygon (with or without holes).
	Each Dictionary contains one outer polygon
	and an array of inner (hole) polygons, that might be empty.
	
	Required, because the return values of the Geometry functions are unsorted.
	"""
	# group polygons
	var outer = []
	var inner = []
	for polygon in polygons:
		if Geometry.is_polygon_clockwise(polygon):
			inner.append(polygon)
		else:
			outer.append(polygon)
	
	# match inner polygons to their outer counterparts
	var results = []
	for outer_polygon in outer:
		var inner_of_outer = []
		# loop backwards to modify the array during iteration
		for inner_index in range(inner.size()-1, -1, -1):
			var inner_polygon = inner[inner_index]
			# an inner polygon belongs to an outer polygon,
			# if any one of it's points is inside the outer polygon
			if Geometry.is_point_in_polygon(inner_polygon[0], outer_polygon):
				inner_of_outer.append(inner_polygon)
				# each inner can only be inside a single outer polygon
				inner.remove(inner_index)
		results.append({
			"outer": outer_polygon,
			"inner": inner_of_outer,
		})
	return results

