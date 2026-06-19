extends Item
class_name SeedItem

## A plantable seed. Planting one on a tilled plot consumes it and starts
## growing `crop`. Sold by merchants like any other Item.

@export var crop: CropData
