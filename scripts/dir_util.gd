class_name DirUtil
extends RefCounted

## Maps a movement/aim vector to a sprite-sheet facing row. Humanoid sheets are
## 8-row, ordered clockwise from south: S=0, SE=1, E=2, NE=3, N=4, NW=5, W=6,
## SW=7. The wolf (and any other 4-row sheet) keeps the cardinal layout
## down=0, up=1, left=2, right=3. The row layout is chosen from the sprite's
## vframes so one helper serves both rigs.

## Octant -> 8-row index. Octant 0 = east, increasing clockwise (screen-space y
## points down, so positive angle is toward the south).
const OCT_TO_ROW := [2, 1, 0, 7, 6, 5, 4, 3]

static func row_for(dir: Vector2, rows: int) -> int:
	if rows >= 8:
		var octant: int = (int(round(dir.angle() / (PI / 4.0))) % 8 + 8) % 8
		return OCT_TO_ROW[octant]
	# 4-row cardinal sheets: the dominant axis wins.
	if absf(dir.x) > absf(dir.y):
		return 3 if dir.x > 0.0 else 2
	return 0 if dir.y > 0.0 else 1
