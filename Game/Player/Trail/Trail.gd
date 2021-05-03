extends Spatial

func _process(delta):
	$MeshInstance.material_override.albedo_color.a -= delta * 2.0
	if $MeshInstance.material_override.albedo_color.a <= 0.0:
		queue_free()
