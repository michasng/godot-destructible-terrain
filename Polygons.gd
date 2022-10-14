class_name Polygons

static func resolve_polygon_holes(polygons: Array) -> Array:
	"""
	Resolves holes in an array of polygons.
	
	Proof of Concept: Currently only works for single holes in an array of two polygons.
	"""
	if polygons.size() == 2:
		if Geometry.is_polygon_clockwise(polygons[0]):
			return [resolve_polygon_hole(polygons[1], polygons[0])]
		elif Geometry.is_polygon_clockwise(polygons[1]):
			return [resolve_polygon_hole(polygons[0], polygons[1])]
	return polygons

# Use Array parameter type, because it exports some functions used here 
static func resolve_polygon_hole(outer: Array, inner: Array) -> PoolVector2Array:
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
	var minimal_distance = INF
	var minimal_distance_index = -1
	for index in range(points.size()):
		var distance = origin.distance_squared_to(points[index])
		if distance < minimal_distance:
			minimal_distance = distance
			minimal_distance_index = index
	return minimal_distance_index


static func _shift_array(arr: Array, begin_index: int) -> Array:
	# module array size to handle indexes beyond the normal range
	if (begin_index % arr.size()) == 0:
		return arr
	var result = arr.slice(begin_index, arr.size() - 1)
	result.append_array(arr.slice(0, begin_index - 1))
	return result

