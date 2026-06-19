class_name UITheme
extends RefCounted

## Single source of truth for Teramor's UI palette and the small set of widget
## builders shared by the code-built panels (shop, storage, crafting, the
## relationship list, the game-over screen and the HUD readouts).
##
## Before this existed, the same brown/parchment/gold colours and near-identical
## `_make_label` / `_make_row_button` / panel-stylebox helpers were copy-pasted
## across half a dozen scripts. Everything routes through here now, so a palette
## tweak is a one-line change.
##
## The matching `res://resources/ui/teramor_theme.tres` mirrors these colours for
## the editor/.tscn side (it is registered as the project default theme). Keep the
## two in sync — this script is the canonical reference.

# --- Palette ----------------------------------------------------------------

## Dark brown panel background (alpha applied per-panel via `panel_style`).
const PANEL_BG := Color(0.164706, 0.12549, 0.094118)
## Warm brown panel border.
const BORDER := Color(0.482353, 0.337255, 0.188235)
## Default parchment body text.
const TEXT := Color(0.913725, 0.886275, 0.831373)
## Green used for speaker names and panel titles.
const ACCENT := Color(0.368627, 0.588235, 0.282353)
## Muted brown for prompts ("[E] Close").
const PROMPT := Color(0.611765, 0.541176, 0.439216)
## Gold for currency.
const GOLD := Color(0.95, 0.85, 0.45)
## Brighter parchment-gold for emphasis (clock readout).
const PARCHMENT := Color(0.95, 0.9, 0.7)
## Sandy tan for secondary titles.
const SAND := Color(0.85, 0.78, 0.55)
## Darker tan accent (storage screen titles).
const TAN := Color(0.72, 0.62, 0.42)
## Greyed-out text for empty/disabled states.
const MUTED := Color(0.7, 0.7, 0.7)
## Danger red (game-over title).
const DANGER := Color(0.85, 0.2, 0.2)

# --- Builders ---------------------------------------------------------------

## Brown panel stylebox used by every code-built PanelContainer. `alpha` lets HUD
## chrome read as semi-transparent while modal panels stay near-opaque.
static func panel_style(alpha: float = 0.96, radius: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_BG, alpha)
	style.set_border_width_all(1)
	style.border_color = BORDER
	style.set_corner_radius_all(radius)
	return style

## A Label backed by LabelSettings (so it ignores any inherited theme and renders
## exactly as specified). Defaults to body text.
static func make_label(text: String, font_size: int = 11, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	label.label_settings = settings
	return label

## A two-column list row button ("Name   123 g") with an optional leading icon,
## shared verbatim by the shop and storage screens.
static func make_row_button(left: String, right: String, icon: Texture2D = null) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(152, 0)
	btn.add_theme_font_size_override("font_size", 10)
	btn.clip_text = true
	if icon != null:
		btn.icon = icon
		btn.expand_icon = false
	btn.text = "%s   %s" % [left, right]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return btn
