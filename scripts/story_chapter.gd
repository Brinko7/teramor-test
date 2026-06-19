extends Resource
class_name StoryChapter

## One beat of the main questline. The Story director starts a chapter's quest,
## and when that quest completes it applies the chapter's rewards/flags, shows a
## toast, and advances to `next_chapter`. Authored as .tres under
## res://resources/story/chapters/ and loaded by the Story autoload.

@export var id: StringName = &""
@export var title: String = "Chapter"
@export_multiline var summary: String = ""

## The main quest that drives this chapter (a Quest .tres path).
@export var quest_path: String = ""
## Story.Stage to enter when this chapter begins.
@export var stage: int = 0
## Shown as a banner when the chapter begins.
@export var intro_toast: String = ""

## --- On completion ----------------------------------------------------------
@export var completion_toast: String = ""
## Story flags set when this chapter completes (gate later dialogue/quests).
@export var set_flags: PackedStringArray = PackedStringArray()
## Bonus skill points granted on completion (e.g. the awakening).
@export var grant_skill_points: int = 0
## Chapter to begin next (&"" ends the main line for now).
@export var next_chapter: StringName = &""
