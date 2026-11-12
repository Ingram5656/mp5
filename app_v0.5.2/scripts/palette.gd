extends RefCounted
## Design tokens from design/设计方案_v1.md.
## Colour is reserved for state: TARGET = in target zone, CAUTION = waiting / near limit, FAULT = error.
## Everything else uses SLATE and STEEL.

# core palette (6)
const PORCELAIN := Color("f6f7f5")   # page background
const SLATE := Color("1c2733")       # text, readouts, pointers, primary button
const STEEL := Color("8794a1")       # scales, secondary text
const TARGET := Color("14a07a")      # in target zone only
const CAUTION := Color("d99a00")     # connecting / near limit
const FAULT := Color("d2483e")       # mistake, overload, disconnected

# derived tints
const SURFACE := Color("ffffff")     # gauge faces, modal
const RULE := Color("dde2e6")        # dividers, hairlines
const TRACK := Color("e4e8eb")       # gauge tracks, progress background
const CONTROL_BORDER := Color("c9d0d6")
const HOVER := Color("eceff1")
const TARGET_TINT := Color("72c6af") # target zone before it is reached (v0.3.1: deeper, about 60% of TARGET)

# type scale (1.25)
const FS_SMALL := 13
const FS_BODY := 16
const FS_LABEL := 20
const FS_TITLE := 25
const FS_READOUT := 49

const FONT_DIR := "res://fonts/"


static func zone_color(mix: float) -> Color:
	return TARGET_TINT.lerp(TARGET, clampf(mix, 0.0, 1.0))
