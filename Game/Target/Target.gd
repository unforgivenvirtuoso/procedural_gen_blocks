extends StaticBody

var game_over := false
var player_won := false

export(float, 0.0, 1.0) var progress = 0.5 setget _set_progress
func _set_progress(value):
	if game_over:
		return
	
	progress = value
	
	$CanvasLayer/MarginContainer/HSlider.value = value
	
	if progress <= 0.0:
		game_over = true
		player_won = true
	elif progress >= 1.0:
		game_over = true
		player_won = false

func _ready():
	self.progress = self.progress
	
	# Set the y position to the block's position
	translation.y = $"../Generator".get_height_at(Vector2(translation.x, translation.z))

func _process(_delta):
	$CanvasLayer/GameOver.visible = game_over
	$CanvasLayer/GameOver/TabContainer.current_tab = 1 if player_won else 0

func _physics_process(delta):
	var delta_progress := 0.0
	for body in $Area.get_overlapping_bodies():
		if "player" in body.get_groups():
			delta_progress -= 1.0
		if "enemy" in body.get_groups():
			delta_progress += 1.0
	
	self.progress += delta_progress * delta * 0.05
