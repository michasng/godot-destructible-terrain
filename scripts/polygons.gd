class_name Polygons


static func clip(polygon_to_clip: PackedVector2Array, clipping_polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	"""
	Clips (i.e. removes) clipping_polygon from polygon_to_clip and resolves any potential holes in them.
	"""
	var clipped_polygons := Geometry2D.clip_polygons(polygon_to_clip, clipping_polygon)
	return resolve_holes(clipped_polygons)


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
				assert(not has_hole(merged))
				
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


static func resolve_holes(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	"""
	Transforms a list of polygons, where some might be clockwise (holes),
	into a list of counter-clockwise polygons.

	Uses a double-edge to connect the vertices of exterior and interior polygons,
	potentially resulting in concave polygons.

	Referece: https://en.wikipedia.org/wiki/Polygon_with_holes
	"""

	var outers: Array[PackedVector2Array]
	var inners: Array[PackedVector2Array]
	for polygon in polygons:
		if Geometry2D.is_polygon_clockwise(polygon):
			inners.push_back(polygon)
		else:
			outers.push_back(polygon)

	var result: Array[PackedVector2Array] = []
	for outer in outers:
		var joined: PackedVector2Array = outer
		for inner in inners:
			# inner might be a hole of a different outer
			if not is_hole_of(outer, inner):
				continue

			var closest_vertex_indices = _find_closest_vertex_indices(joined, inner)
			var outer_index = closest_vertex_indices[0]
			var inner_index = closest_vertex_indices[1]
			joined = joined.slice(0, outer_index + 1) + inner.slice(inner_index) + inner.slice(0, inner_index + 1) + joined.slice(outer_index)
		result.push_back(joined)
	
	return result


static func _find_closest_vertex_indices(polygon1: PackedVector2Array, polygon2: PackedVector2Array) -> Array[int]:
	var minimal_distance := INF
	var minimal_distance_indexes: Array[int]
	for i in range(polygon1.size()):
		for j in range(polygon2.size()):
			var distance := polygon1[i].distance_squared_to(polygon2[j])
			if distance < minimal_distance:
				minimal_distance = distance
				minimal_distance_indexes = [i, j]
	return minimal_distance_indexes


static func has_hole(polygons: Array[PackedVector2Array]) -> bool:
	"""
	Right-hand rule:
	Exterior (outer) polygons are in counterclockwise order.
	Interior polygons (holes) are in clockwise order.
	"""
	return polygons.any(func(polygon): return Geometry2D.is_polygon_clockwise(polygon))


static func is_hole_of(outer: PackedVector2Array, inner: PackedVector2Array) -> bool:
	assert(not Geometry2D.is_polygon_clockwise(outer))
	assert(Geometry2D.is_polygon_clockwise(inner))

	var clipped_polygons := Geometry2D.clip_polygons(outer, inner)
	return clipped_polygons.size() == 2
