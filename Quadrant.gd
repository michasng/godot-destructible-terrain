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

	# remove any existing polygons from the new one
	for colpol in static_body.get_children():
		# avoid changing intersected_adding_polygons during iteration
		var new_intersected_adding_polygons = []
		for intersected_adding_polygon in intersected_adding_polygons:
			var clip_results = Geometry.clip_polygons_2d(intersected_adding_polygon, colpol.polygon)
			if _is_hole(clip_results):
				# the colpol must be contained in the adding_polygon
				# clear the colpol and ignore the hole
				colpol.queue_free()
				for clip_result in clip_results:
					if not Geometry.is_polygon_clockwise(clip_result):
						new_intersected_adding_polygons.append(clip_result)
				break
			if len(clip_results) > 0:
				new_intersected_adding_polygons.append_array(clip_results)
		intersected_adding_polygons = new_intersected_adding_polygons
	
	for intersected_adding_polygon in intersected_adding_polygons:
		static_body.add_child(_new_colpol(intersected_adding_polygon))


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


func _split_quadrant(split_x: int):
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


func _is_hole(clipped_polygons):
	"""
	If either of the two polygons after clipping
	are clockwise, then you have carved a hole
	"""
	return len(clipped_polygons) == 2 and (
			Geometry.is_polygon_clockwise(clipped_polygons[0]) or
			Geometry.is_polygon_clockwise(clipped_polygons[1])
		)


func _avg_position(array: Array):
	"""
	Average 2D position in an
	array of positions
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
