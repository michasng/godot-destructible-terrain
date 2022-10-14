extends Node2D

var default_quadrant_polygon: Array = []
onready var static_body = $StaticBody2D
onready var ColPol = preload("res://ColPol.tscn")

func _ready():
	init_quadrant()


func init_quadrant():
	"""
	Initiates the default (square) ColPol
	"""
	static_body.add_child(_new_colpol(default_quadrant_polygon))


func reset_quadrant():
	"""
	Removes all collision polygons
	and initiates the default ColPol
	"""
	for colpol in static_body.get_children():
		colpol.queue_free()
	init_quadrant()


func carve(clipping_polygon: PoolVector2Array):
	"""
	Carves `clipping_polygon` away from the quadrant
	"""
	for colpol in static_body.get_children():
		var clipped_polygons = _clip_without_hole(colpol.polygon, clipping_polygon)
		var n_clipped_polygons = len(clipped_polygons)
		match n_clipped_polygons:
			0:
				# clipping_polygon completely overlaps colpol
				colpol.queue_free()
			1:
				# Clipping produces only one polygon
				colpol.update_pol(clipped_polygons[0])
			_:
				# if more polygons, simply add all of them to the quadrant
				colpol.update_pol(clipped_polygons[0])
				for i in range(n_clipped_polygons-1):
					static_body.add_child(_new_colpol(clipped_polygons[i+1]))


func add(adding_polygon: PoolVector2Array):
	"""
	Adds the intersecting parts of `adding_polygon` to the quadrant
	"""
	var intersected_adding_polygons = Geometry.intersect_polygons_2d(default_quadrant_polygon, adding_polygon)
	if len(intersected_adding_polygons) == 0:
		# adding_polygon is not within the quadrant
		return
	if _is_hole(intersected_adding_polygons):
		# adding_polygon must be completely enclosed by the quadrant
		intersected_adding_polygons = [adding_polygon]

	var polygons = []
	for child in static_body.get_children():
		polygons.append(child.polygon)
	polygons.append_array(intersected_adding_polygons)
	polygons = _merge_polygons(polygons)
	_assign_polygons(polygons)


func _assign_polygons(polygons: Array):
	for child in static_body.get_children():
		child.queue_free()
	for polygon in polygons:
		static_body.add_child(_new_colpol(polygon))


func _merge_polygons(polygons_to_merge: Array) -> Array:
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
				merged = Polygons.resolve_polygon_holes(merged)	
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


func _clip_without_hole(polygon: Array, clip_polygon: Array):
	"""
	Returns two polygons produced by vertically
	splitting polygon in half and removing clip_polygon.
	"""
	var clipped_polygons = Geometry.clip_polygons_2d(polygon, clip_polygon)
	if not _is_hole(clipped_polygons):
		# no hole was created
		return clipped_polygons
	# split the quadrant at the polygons position to avoid creating a hole
	var avg_x = _avg_position(clip_polygon).x
	var subquadrants = _split_quadrant(avg_x)
	var left_quadrant_clipped = Geometry.clip_polygons_2d(subquadrants[0], clip_polygon)[0]
	var right_quadrant_clipped = Geometry.clip_polygons_2d(subquadrants[1], clip_polygon)[0]
	var left_polygon_clipped = Geometry.intersect_polygons_2d(left_quadrant_clipped, polygon)[0]
	var right_polygon_clipped = Geometry.intersect_polygons_2d(right_quadrant_clipped, polygon)[0]
	return [left_polygon_clipped, right_polygon_clipped]


func _split_quadrant(split_x: int) -> Array:
	"""
	Returns a list of polygons as a result of
	splitting default_quadrant_polygon vertically at split_x
	"""
	var left_subquadrant = default_quadrant_polygon.duplicate()
	left_subquadrant[1] = Vector2(split_x, left_subquadrant[1].y)
	left_subquadrant[2] = Vector2(split_x, left_subquadrant[2].y)
	var right_subquadrant = default_quadrant_polygon.duplicate()
	right_subquadrant[0] = Vector2(split_x, right_subquadrant[0].y)
	right_subquadrant[3] = Vector2(split_x, right_subquadrant[3].y)
	return [left_subquadrant, right_subquadrant]


func _is_hole(polygons) -> bool:
	"""
	A hole was created if either polygon is clockwise.
	"""
	for polygon in polygons:
		if Geometry.is_polygon_clockwise(polygon):
			return true
	return false


func _avg_position(array: Array) -> Vector2:
	"""
	Returns the average 2D position in an array of points.
	"""
	var sum = Vector2()
	for p in array:
		sum += p
	return sum/len(array)


func _new_colpol(polygon):
	"""
	Returns ColPol instance
	with assigned polygon
	"""
	var colpol = ColPol.instance()
	colpol.polygon = polygon
	return colpol
