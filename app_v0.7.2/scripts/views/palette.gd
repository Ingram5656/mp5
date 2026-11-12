extends RefCounted
## Design tokens — design/设计方案_v2.0.md "菜园木牌" (v0.7.0). Replaces the v1.1 tokens.
## The old constant names (SLATE, STEEL, TARGET …) are kept so every view picks up the new look; their
## meaning is the same (text, secondary, in-target …), only the colours changed.
## Colour groups: world colours (sky, wood, paper, ink, soil) may cover large areas; CARROT = the one
## main action per page; LEAF / SUN / TOMATO = state only.

# ---- world
const SKY := Color("5cc8f8")         # page background (behind the garden backdrop)
const PLANK := Color("f7cf8a")       # wooden signs
const PLANK_EDGE := Color("e3a24a")  # thickness under signs, posts
const PAPER := Color("fff4df")       # plates, report paper, secondary buttons, tags
const INK := Color("5e3410")         # every outline, body text, readouts
const SOIL := Color("85572f")        # secondary text, scales, score bars (v2.0 draft #9A6A44, darkened for 5:1 contrast on paper)
const SKY_DEEP := Color("2e8fc4")    # standard curve in charts
# ---- action
const CARROT := Color("ff7f1f")      # the main button of a page, pointer heads
const CARROT_DEEP := Color("c95a0c")
# ---- state (fills)
const LEAF := Color("5fb52a")        # in target zone, unlocked, cleared
const LEAF_TINT := Color("b9e38f")   # target zone before it is reached
const SUN := Color("ffc531")         # waiting, connecting, near the limit
const TOMATO := Color("e8442e")      # mistake, overload, disconnected, limit lines, F
# ---- state (text on paper / wood: darker so it stays readable)
const LEAF_TEXT := Color("2f7212")
const SUN_TEXT := Color("8a5a00")
const TOMATO_TEXT := Color("c0321e")

# ---- v1.1 names, mapped onto the v2.0 colours (used throughout the views)
const PORCELAIN := SKY
const SLATE := INK
const STEEL := SOIL
const TARGET := LEAF
const TARGET_TINT := LEAF_TINT
const CAUTION := SUN
const FAULT := TOMATO
const SURFACE := Color("fffdf7")       # gauge faces, chart backgrounds (whiter than paper)
const RULE := Color("e6cfa6")          # light lines on paper (list separators)
const TRACK := Color("f6e7c8")         # empty part of bars and rings
const CONTROL_BORDER := INK
const HOVER := Color("ffe6b8")

# ---- shape
const LINE := 2                  # outline width at the 1152×648 window
const LIP := 4                   # solid "thickness" under buttons and signs

# ---- type scale (1.25); 39 added in v2.0
const FS_SMALL := 13
const FS_BODY := 16
const FS_LABEL := 20
const FS_TITLE := 25
const FS_HEAD := 31
const FS_DISPLAY := 39
const FS_READOUT := 49

const FONT_DIR := "res://fonts/"
const UI_DIR := "res://assets/ui/"
const GARDEN_DIR := "res://assets/carrot_game/"


static func zone_color(mix: float) -> Color:
	return LEAF_TINT.lerp(LEAF, clampf(mix, 0.0, 1.0))
