extends KinematicBody

var health := 5

func _ready():
	# Set the y position to the block's position, plus half of the height (0.5)
	translation.y = $"../Generator".get_height_at(Vector2(translation.x, translation.z)) + 0.5

# Velocity of the enemy
var velocity := Vector3()

func _physics_process(delta):
	var player = get_tree().get_nodes_in_group("player")[0]
	
	# Increase velocity downwards (gravity)
	velocity.y -= delta * 10.0
	velocity *= (1.0 - delta)
	
	var movement := Vector3.ZERO
	
	# Up/Down movement
	movement += velocity
	
	var target := Vector3.UP * translation.y
	var targetting_player := false
	if target.distance_squared_to(translation) < pow(1.0, 2.0):
		target = player.translation
		targetting_player = true
	
	look_at(target, Vector3.UP)
	
	# Forward/Backward movement
	velocity -= 0.1 * transform.basis.z
	
	# Move the player.
	move_and_slide(movement, Vector3.UP)
	
	var player_colliding := false
	for i in get_slide_count():
		if get_slide_collision(i).collider == player:
			player_colliding = true
	
	if player_colliding and targetting_player:
		var dir = target - translation
		dir.y = 0.0
		dir = dir.normalized()
		player.hurt(dir)
	
	if (not player_colliding or targetting_player):
		if is_on_floor() and (is_on_wall() or targetting_player):
			velocity.y = 5.0

var hurt_activity := 0.0

func _process(delta):
	hurt_activity -= 2.0 * delta
	hurt_activity = max(hurt_activity, 0.0)
	$MeshInstance.material_override.albedo_color = Color.white.linear_interpolate(Color.red, hurt_activity)

func hurt(direction: Vector3) -> void:
	hurt_activity = 1.0
	health -= 1
	velocity += direction * 5.0
	if health == 0:
		get_tree().current_scene.spawn_enemy_after()
		queue_free()
