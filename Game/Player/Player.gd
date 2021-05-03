extends KinematicBody

func _ready():
	# Set mouse mode to captured (Hide mouse and force it to be centered)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Set the y position to the block's position, plus half of the height (1)
	translation.y = $"../Generator".get_height_at(Vector2(translation.x, translation.z)) + 1

func _input(event):
	# Hit escape to quit game
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	# Mouse motion
	if event is InputEventMouseMotion:
		# Horizontal movement: Rotate player on Y axis
		rotate_y(-event.relative.x * 0.007)
		
		# Vertical movement: Rotate camera pivot on X axis, clamp it between -0.6 and 1.2 radians
		$CameraPivot.rotate_x(-event.relative.y * 0.004)
		$CameraPivot.rotation.x = clamp($CameraPivot.rotation.x, -0.6, 1.2)
	# Attack buttons
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == BUTTON_LEFT:
			var state: PhysicsDirectSpaceState = get_world().direct_space_state
			var base := translation - Vector3.UP * 0.5
			var origin := base + transform.basis.z * 1.0
			var target := base - transform.basis.z * 2.0
			
			var result := state.intersect_ray(origin, target, [$DashArea], 2, false, true)
			if result.has("collider"):
				var enemy = result["collider"].get_parent()
				if "enemy" in enemy.get_groups():
					enemy.hurt(-result["normal"])
		if not dash_cooldown and event.pressed and event.button_index == BUTTON_RIGHT:
			dash_cooldown = true
			dashing = true
			for _i in 4:
				var trail := preload("res://Game/Player/Trail/Trail.tscn").instance()
				trail.translation = translation
				get_tree().current_scene.add_child(trail)
				yield(get_tree().create_timer(0.05), "timeout")
			dash_ignore_list.clear()
			dashing = false
			yield(get_tree().create_timer(1.0), "timeout")
			dash_cooldown = false

# Velocity of the player
var velocity := Vector3()

var dash_cooldown := false
var dashing := false
var dash_ignore_list := []

func _physics_process(delta):
	$CollisionShape.disabled = dashing
	if dashing:
		translation -= transform.basis.z * 10.0 * delta
		for body in $DashArea.get_overlapping_bodies():
			if not "player" in body.get_groups():
				dashing = false
		for area in $DashArea.get_overlapping_areas():
			if not area in dash_ignore_list:
				dash_ignore_list.push_back(area)
				if "enemy" in area.get_parent().get_groups():
					for _i in 2:
						area.get_parent().hurt(-transform.basis.z)
		return
	
	# Increase velocity downwards (gravity)
	velocity.y -= delta * 10.0
	velocity *= (1.0 - delta)
	var xz_velocity := Vector2(velocity.x, velocity.z)
	xz_velocity *= (1.0 - delta * 4.0)
	velocity = Vector3(xz_velocity.x, velocity.y, xz_velocity.y)
	
	var movement := Vector3.ZERO
	# Up/Down movement
	movement += velocity
	# Forward/Backward movement
	movement += 5.0 * transform.basis.z * (Input.get_action_strength("Back") - Input.get_action_strength("Forward"))
	# Left/Right movement
	movement += 5.0 * transform.basis.x * (Input.get_action_strength("Right") - Input.get_action_strength("Left"))
	
	# Move the player.
	move_and_slide(movement, Vector3.UP)
	
	# If the player is on the ground, reset the velocity and allow jumping
	if is_on_floor():
		velocity.y = 0.0
		if Input.is_action_pressed("Jump"):
			velocity.y = 5.0
	
	# Clamp the player's X/Z position to be within 40 metres of the center of the world.
	var xz := Vector2(translation.x, translation.z)
	xz = xz.clamped(40.0)
	translation = Vector3(xz.x, translation.y, xz.y)

var hurt_activity := 0.0

func _process(delta):
	hurt_activity -= 2.0 * delta
	hurt_activity = max(hurt_activity, 0.0)
	$MeshInstance.material_override.albedo_color = Color.white.linear_interpolate(Color.red, hurt_activity)

func hurt(direction: Vector3) -> void:
	hurt_activity = 1.0
	velocity += direction * 2.0
