extends Item
class_name ToolItem

## A farm tool held in the bag. `tool_kind` selects the action a FarmPlot offers
## when the player carries it: "hoe" tills bare soil, "watering_can" waters a
## planted crop. Tools are not consumed on use.

@export var tool_kind: StringName = &""
