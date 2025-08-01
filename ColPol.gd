class_name ColPol
extends CollisionPolygon2D

@onready var visual_polygon: Polygon2D = $Polygon2D


func _ready() -> void:
	visual_polygon.polygon = polygon


func update_pol(polygon_points: PackedVector2Array) -> void:
	polygon = polygon_points
	visual_polygon.polygon = polygon
