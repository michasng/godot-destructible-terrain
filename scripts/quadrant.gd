class_name Quadrant
extends Node2D

var default_quadrant_polygon: PackedVector2Array = []
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var CollisionPolygonScene: PackedScene = preload("res://scenes/collision_polygon.tscn")


func _ready() -> void:
	init_quadrant()


func init_quadrant() -> void:
	"""
	Initiates the default (square) ColPol
	"""
	static_body.add_child(_new_colpol(default_quadrant_polygon))


func reset_quadrant() -> void:
	"""
	Removes all collision polygons
	and initiates the default ColPol
	"""
	for colpol in static_body.get_children():
		colpol.queue_free()
	init_quadrant()


func carve(clipping_polygon: PackedVector2Array) -> void:
	"""
	Carves `clipping_polygon` away from the quadrant
	"""
	for colpol in static_body.get_children():
		var clipped_polygons := Polygons.clip(colpol.polygon, clipping_polygon)
		
		match clipped_polygons.size():
			0:
				# clipping_polygon completely overlaps colpol
				colpol.queue_free()
			1:
				# Clipping produces only one polygon
				colpol.update_pol(clipped_polygons[0])
			_:
				# if more polygons, simply add all of them to the quadrant
				colpol.update_pol(clipped_polygons[0])
				for i in range(clipped_polygons.size() - 1):
					static_body.add_child(_new_colpol(clipped_polygons[i + 1]))


func add(adding_polygon: PackedVector2Array) -> void:
	"""
	Adds the intersecting parts of `adding_polygon` to the quadrant
	"""
	var intersected_adding_polygons := Geometry2D.intersect_polygons(default_quadrant_polygon, adding_polygon)
	if len(intersected_adding_polygons) == 0:
		# adding_polygon is not within the quadrant
		return
	if Polygons.has_hole(intersected_adding_polygons):
		# adding_polygon must be completely enclosed by the quadrant
		intersected_adding_polygons = [adding_polygon]

	var polygons: Array[PackedVector2Array] = []
	for child in static_body.get_children():
		polygons.append(child.polygon)
	polygons.append_array(intersected_adding_polygons)
	polygons = Polygons.merge(polygons)
	
	assert(not Polygons.has_hole(polygons))
	
	_assign_polygons(polygons)


func _assign_polygons(polygons: Array[PackedVector2Array]) -> void:
	for child in static_body.get_children():
		child.queue_free()
	for polygon in polygons:
		var colpol = _new_colpol(polygon)
		static_body.add_child(colpol) # sometimes throws "Convex decomposing failed"


func _new_colpol(polygon: PackedVector2Array) -> CollisionPolygon:
	var collision_polygon: CollisionPolygon = CollisionPolygonScene.instantiate()
	collision_polygon.polygon = polygon
	return collision_polygon
