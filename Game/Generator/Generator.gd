extends Spatial

# Map size on X and Z axis. Y axis is effectively infinite.
export var map_size := Vector2(256, 256)

# Chunk size on X and Z axis.
# Larger chunks mean less nodes, but less accurate culling and slower updates.
# Smaller chunks mean more nodes, but more accurate culling and faster updates.
export var chunk_size := Vector2(64, 64)

# Base height map for voxels.
export var height_map: OpenSimplexNoise
# Multiply the height map by this for mountainous/flat regions.
export var height_mult_map: OpenSimplexNoise

export var base_height := 0
export var height_range := 64

var chunks := {}
func chunk_pos3(pos: Vector3) -> Vector2:
	return chunk_pos(Vector2(pos.x, pos.z))
func chunk_pos(pos: Vector2) -> Vector2:
	return (pos / chunk_size).floor()

func chunk_local3(pos: Vector3) -> Vector3:
	var local := chunk_local(Vector2(pos.x, pos.z))
	var result := Vector3(local.x, pos.y, local.y)
	return result
func chunk_local(pos: Vector2) -> Vector2:
	return pos.posmodv(chunk_size)

func chunk_data(pos: Vector2) -> Dictionary:
	if not chunks.has(pos):
		chunks[pos] = {}
	
	return chunks[pos]

func _ready():
	generate()
	load_all_chunks()

func generate() -> void:
	randomize()
	generate_voxels()
	generate_buildings()

func get_height_at(pos: Vector2) -> int:
	return base_height + int(round(
		height_range
				* height_map.get_noise_2dv(pos)
				* lerp(0.0, 0.5, height_mult_map.get_noise_2dv(pos))
	))

func generate_voxels() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	height_map.seed = rng.randi()
	height_mult_map.seed = rng.randi()
	
	for x in range(-map_size.x / 2.0, map_size.x / 2.0):
		for z in range(-map_size.y / 2.0, map_size.y / 2.0):
			var xz := Vector2(x, z)
			var height := get_height_at(xz)
			var chunk := chunk_data(chunk_pos(xz))
			var pos := chunk_local(xz)
			
			for i in 2:
				chunk[Vector3(pos.x, height - i - 1, pos.y)] = "Grass" if i == 0 else "Dirt"

func generate_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	for _i in 40:
		var phi = rng.randf() * TAU
		var r = lerp(20.0, 100.0, rng.randf())
		
		var sx := rng.randi_range(3, 6)
		var sy := rng.randi_range(3, 6)
		var sz := rng.randi_range(3, 6)
		
		var px := int(cos(phi) * r)
		var pz := int(sin(phi) * r)
		var py := INF
		for i in sx:
			for j in sz:
				py = min(py, get_height_at(Vector2(px + i, pz + j)))
		
		for i in sx:
			for j in sy:
				for k in sz:
					var pos := Vector3(px + i, py + j, pz + k)
					var chunk_pos := chunk_pos3(pos)
					var chunk_local := chunk_local3(pos)
					var chunk := chunk_data(chunk_pos)
					
					chunk[chunk_local] = "Wood"

func transparent_at(pos: Vector3) -> bool:
	var chunk := chunk_data(chunk_pos3(pos))
	var local := chunk_local3(pos)
	return not chunk.has(local)

func load_all_chunks():
	for chunk_pos in chunks.keys():
		var chunk: Dictionary = chunks[chunk_pos]
		
		var static_body := StaticBody.new()
		
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for pos in chunk.keys():
			var global_pos: Vector3 = pos
			var offset_xz: Vector2 = chunk_size * chunk_pos
			global_pos += Vector3(offset_xz.x, 0.0, offset_xz.y)
			
			var type: String = chunk[pos]
			var uv := Rect2(0.0, 0.0, 0.5, 0.5)
			
			assert(not transparent_at(global_pos))
			
			match type:
				"Grass":
					uv.position = Vector2(0.0, 0.0)
				"Dirt":
					uv.position = Vector2(0.0, 0.5)
				"Wood":
					uv.position = Vector2(0.5, 0.5)
			# TOP FACE
			if not chunk.has(pos + Vector3.UP):
				surface.add_uv(uv.position)
				surface.add_vertex(pos + Vector3(0.0, 1.0, 0.0))
				surface.add_uv(uv.position + Vector2.RIGHT * uv.size)
				surface.add_vertex(pos + Vector3(1.0, 1.0, 0.0))
				surface.add_uv(uv.end)
				surface.add_vertex(pos + Vector3(1.0, 1.0, 1.0))
				surface.add_uv(uv.position)
				surface.add_vertex(pos + Vector3(0.0, 1.0, 0.0))
				surface.add_uv(uv.end)
				surface.add_vertex(pos + Vector3(1.0, 1.0, 1.0))
				surface.add_uv(uv.position + Vector2.DOWN * uv.size)
				surface.add_vertex(pos + Vector3(0.0, 1.0, 1.0))
			match type:
				"Grass":
					uv.position = Vector2(0.0, 0.5)
			# BOTTOM FACE
			if not chunk.has(pos + Vector3.DOWN):
				surface.add_uv(uv.position)
				surface.add_vertex(pos + Vector3(1.0, 0.0, 0.0))
				surface.add_uv(uv.position + Vector2.RIGHT * uv.size)
				surface.add_vertex(pos + Vector3(0.0, 0.0, 0.0))
				surface.add_uv(uv.end)
				surface.add_vertex(pos + Vector3(0.0, 0.0, 1.0))
				surface.add_uv(uv.position)
				surface.add_vertex(pos + Vector3(1.0, 0.0, 0.0))
				surface.add_uv(uv.end)
				surface.add_vertex(pos + Vector3(0.0, 0.0, 1.0))
				surface.add_uv(uv.position + Vector2.DOWN * uv.size)
				surface.add_vertex(pos + Vector3(1.0, 0.0, 1.0))
			match type:
				"Grass":
					uv.position = Vector2(0.5, 0.0)
			# NORTH FACE
			if not chunk.has(pos + Vector3.BACK):
				surface.add_uv(uv.position)
				surface.add_vertex(pos + Vector3(0.0, 1.0, 1.0))
				surface.add_uv(uv.position + Vector2.RIGHT * uv.size)
				surface.add_vertex(pos + Vector3(1.0, 1.0, 1.0))
				surface.add_uv(uv.end)
				surface.add_vertex(pos + Vector3(1.0, 0.0, 1.0))
				surface.add_uv(uv.position)
				surface.add_vertex(pos + Vector3(0.0, 1.0, 1.0))
				surface.add_uv(uv.end)
				surface.add_vertex(pos + Vector3(1.0, 0.0, 1.0))
				surface.add_uv(uv.position + Vector2.DOWN * uv.size)
				surface.add_vertex(pos + Vector3(0.0, 0.0, 1.0))
			# EAST FACE
			if not chunk.has(pos + Vector3.LEFT):
				surface.add_uv(uv.position)
				surface.add_vertex(pos + Vector3(0.0, 1.0, 0.0))
				surface.add_uv(uv.position + Vector2.RIGHT * uv.size)
				surface.add_vertex(pos + Vector3(0.0, 1.0, 1.0))
				surface.add_uv(uv.end)
				surface.add_vertex(pos + Vector3(0.0, 0.0, 1.0))
				surface.add_uv(uv.position)
				surface.add_vertex(pos + Vector3(0.0, 1.0, 0.0))
				surface.add_uv(uv.end)
				surface.add_vertex(pos + Vector3(0.0, 0.0, 1.0))
				surface.add_uv(uv.position + Vector2.DOWN * uv.size)
				surface.add_vertex(pos + Vector3(0.0, 0.0, 0.0))
			# SOUTH FACE
			if not chunk.has(pos + Vector3.FORWARD):
				surface.add_uv(uv.position)
				surface.add_vertex(pos + Vector3(1.0, 1.0, 0.0))
				surface.add_uv(uv.position + Vector2.RIGHT * uv.size)
				surface.add_vertex(pos + Vector3(0.0, 1.0, 0.0))
				surface.add_uv(uv.end)
				surface.add_vertex(pos + Vector3(0.0, 0.0, 0.0))
				surface.add_uv(uv.position)
				surface.add_vertex(pos + Vector3(1.0, 1.0, 0.0))
				surface.add_uv(uv.end)
				surface.add_vertex(pos + Vector3(0.0, 0.0, 0.0))
				surface.add_uv(uv.position + Vector2.DOWN * uv.size)
				surface.add_vertex(pos + Vector3(1.0, 0.0, 0.0))
			# WEST FACE
			if not chunk.has(pos + Vector3.RIGHT):
				surface.add_uv(uv.position)
				surface.add_vertex(pos + Vector3(1.0, 1.0, 1.0))
				surface.add_uv(uv.position + Vector2.RIGHT * uv.size)
				surface.add_vertex(pos + Vector3(1.0, 1.0, 0.0))
				surface.add_uv(uv.end)
				surface.add_vertex(pos + Vector3(1.0, 0.0, 0.0))
				surface.add_uv(uv.position)
				surface.add_vertex(pos + Vector3(1.0, 1.0, 1.0))
				surface.add_uv(uv.end)
				surface.add_vertex(pos + Vector3(1.0, 0.0, 0.0))
				surface.add_uv(uv.position + Vector2.DOWN * uv.size)
				surface.add_vertex(pos + Vector3(1.0, 0.0, 1.0))
		
		surface.generate_normals()
		
		var mesh := surface.commit()
		var instance := MeshInstance.new()
		instance.mesh = mesh
		var material := SpatialMaterial.new()
		material.albedo_texture = load("res://texture.png")
		instance.material_override = material
		instance.name = "Chunk" + str(chunk_pos)
		
		var real_pos2: Vector2 = chunk_pos * chunk_size
		var real_pos := Vector3(real_pos2.x, 0.0, real_pos2.y)
		instance.translation = real_pos
		
		instance.create_trimesh_collision()
		
		add_child(instance)
