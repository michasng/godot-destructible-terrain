class_name TestPolygons
extends Node

func _ready():
	_test_resolve_holes()


func _test_resolve_holes():
	var outer = [
		Vector2(500, 0),
		Vector2(500, 500),
		Vector2(0, 500),
		Vector2(0, 0),
	]
	
	var inner1 = [
		Vector2(100, 200),
		Vector2(200, 200),
		Vector2(200, 100),
		Vector2(100, 100),
	]
	
	var inner2 = [
		Vector2(300, 400),
		Vector2(400, 400),
		Vector2(400, 300),
		Vector2(300, 300),
	]
	
	var result = Polygons.resolve_holes([outer, inner2, inner1])
	print(result)
	$Polygon2D.polygon = result[0]
