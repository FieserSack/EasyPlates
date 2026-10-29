EasyPlates = EasyPlates or {}

EasyPlates.Defaults = {
	width = 120,
	height = 12,
	castHeight = 10,
	castWidthScale = 1.0, -- Castbar inkl. Icon: volle Plate-Breite

	texture = "Interface\\TargetingFrame\\UI-StatusBar",
	border = true,
	borderSize = 1,

	font = "Fonts\\FRIZQT__.TTF",
	fontSize = 11,
	fontOutline = "OUTLINE",

	showLevel = true,
	showCastbar = true,
	showElite = true,
	showRaidIcon = true,
	showThreat = true,
	showAuras = true,
	showBuffs = true,
	showDebuffs = true,
	-- Aura icons match cast-spell icon size (castHeight + 2)
	auraSize = 12,
	auraSpacing = 3,
	auraMax = 16,

	colors = {
		hostile = { 0.78, 0.25, 0.25 },
		neutral = { 0.90, 0.80, 0.20 },
		friendly = { 0.30, 0.75, 0.30 },
		tapped = { 0.55, 0.55, 0.55 },
		cast = { 0.85, 0.70, 0.20 },
		castInterruptible = { 0.20, 0.70, 0.90 },
		background = { 0.10, 0.10, 0.10, 0.80 },
		border = { 0, 0, 0, 1 },
		targetBorder = { 1.00, 0.95, 0.15, 1 }, -- leuchtendes Gelb
		name = { 1, 1, 1 },
		level = { 1, 0.90, 0.40 },
	},

	alpha = {
		target = 1.0,
		nonTarget = 0.85,
		occluded = 0.55,
	},

	scale = {
		target = 1.15,
		normal = 1.0,
	},
}
