extends Node2D

## Demo cycler for the LPC paper-doll: walks the character in each direction and
## fires slash / shoot / spellcast so the whole rig can be validated from screenshots.

@onready var c: LPCCharacter = $Char
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	match int(_t) % 12:
		0, 1, 2:
			c.set_facing(0); c.play("walk")    # walk down
		3:
			c.play("slash")
		4, 5:
			c.set_facing(3); c.play("walk")    # walk right
		6:
			c.play("shoot")
		7, 8:
			c.set_facing(1); c.play("walk")    # walk up
		9:
			c.play("spellcast")
		_:
			c.set_facing(2); c.play("walk")    # walk left
