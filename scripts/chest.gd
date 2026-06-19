extends Area2D

## A camp storage chest. Implements the shared INTERACT contract (collision layer
## 32, the "interactable" group, plus `interact(player)`). Interacting opens the
## global StorageUI for the shared camp stash, so any chest reaches the same
## storage. Purely a view + interaction hook; the items live in StorageManager.

func _ready() -> void:
	add_to_group("interactable")

func interact(_player) -> void:
	StorageUI.open()
