EasyPlates = EasyPlates or {}
local EP = EasyPlates

function EP.CreateVisual(parent)
	local db = EP.db
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetFrameLevel((parent:GetFrameLevel() or 0) + 10)
	frame:Hide()

	-- Anchor container fills the blizzard plate; content is laid out inside
	frame:SetAllPoints(parent)

	local content = CreateFrame("Frame", nil, frame)
	content:SetWidth(db.width)
	content:SetHeight(db.height + 18)
	content:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame.content = content

	-- Health background
	local bg = content:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(db.texture)
	bg:SetVertexColor(unpack(db.colors.background))
	bg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -14)
	bg:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -14)
	bg:SetHeight(db.height)
	frame.bg = bg

	-- Health bar
	local health = CreateFrame("StatusBar", nil, content)
	health:SetStatusBarTexture(db.texture)
	health:SetMinMaxValues(0, 1)
	health:SetValue(1)
	health:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)
	health:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 0, 0)
	frame.health = health

	-- Primary + secondary health text as StatusBar children (draw above bar fill)
	local healthText = health:CreateFontString(nil, "OVERLAY")
	healthText:SetFont(db.font, EP.GetHealthTextFontSize(db), db.fontOutline)
	healthText:SetTextColor(1, 1, 1)
	healthText:SetShadowOffset(1, -1)
	EP.AnchorHealthText(healthText, health, db.healthTextAlign)
	healthText:SetText("")
	frame.healthText = healthText

	local healthText2 = health:CreateFontString(nil, "OVERLAY")
	healthText2:SetFont(db.font, EP.GetHealthTextFontSize(db), db.fontOutline)
	healthText2:SetTextColor(1, 1, 1)
	healthText2:SetShadowOffset(1, -1)
	EP.AnchorHealthText(healthText2, health, db.healthTextAlign2)
	healthText2:SetText("")
	frame.healthText2 = healthText2

	-- Border (3.3.5a-compatible edge texture)
	if db.border then
		local border = CreateFrame("Frame", nil, health)
		border:SetPoint("TOPLEFT", -2, 2)
		border:SetPoint("BOTTOMRIGHT", 2, -2)
		border:SetBackdrop({
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 12,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		})
		border:SetBackdropBorderColor(unpack(db.colors.border))
		frame.border = border
	end

	-- Threat % (above bar, right)
	local threat = content:CreateFontString(nil, "OVERLAY")
	threat:SetFont(db.font, db.fontSize - 1, db.fontOutline)
	threat:SetPoint("BOTTOMRIGHT", bg, "TOPRIGHT", 0, 2)
	threat:SetJustifyH("RIGHT")
	threat:SetShadowOffset(1, -1)
	threat:Hide()
	frame.threat = threat

	-- Level (right of health bar)
	local level = content:CreateFontString(nil, "OVERLAY")
	level:SetFont(db.font, db.fontSize - 1, db.fontOutline)
	level:SetPoint("LEFT", bg, "RIGHT", 4, 0)
	level:SetJustifyH("LEFT")
	level:SetTextColor(unpack(db.colors.level))
	frame.level = level

	-- Elite / rare marker (right of level)
	local elite = content:CreateTexture(nil, "OVERLAY")
	elite:SetWidth(14)
	elite:SetHeight(14)
	elite:SetPoint("LEFT", level, "RIGHT", 3, 0)
	elite:Hide()
	frame.elite = elite

	-- Name (above bar; raid icon sits left of name+bar as a tall block)
	local name = content:CreateFontString(nil, "OVERLAY")
	name:SetFont(db.font, db.fontSize, db.fontOutline)
	name:SetPoint("BOTTOMLEFT", bg, "TOPLEFT", 0, 2)
	name:SetPoint("RIGHT", threat, "LEFT", -4, 0)
	name:SetJustifyH("LEFT")
	name:SetTextColor(unpack(db.colors.name))
	name:SetShadowOffset(1, -1)
	frame.name = name

	-- Raid target: left of name + health bar (10% under combined height)
	local raid = content:CreateTexture(nil, "OVERLAY")
	EP.AnchorRaidIcon(raid, name, bg, db)
	raid:Hide()
	frame.raid = raid

	-- 1) Aura slot directly under health (reserved so cast below doesn't jump)
	local auraSlot = CreateFrame("Frame", nil, content)
	local auraH = EP.GetCastSpellIconSize(db)
	auraSlot:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", 0, -2)
	auraSlot:SetPoint("TOPRIGHT", bg, "BOTTOMRIGHT", 0, -2)
	auraSlot:SetHeight(auraH)
	frame.auraSlot = auraSlot

	-- Buff / Debuff icons in the aura slot
	EP.CreateAuraBar(content, frame)

	-- 2) Cast slot below auras — full plate width (icon + bar)
	local castSlot = CreateFrame("Frame", nil, content)
	local spellSize = EP.GetCastSpellIconSize(db)
	castSlot:SetPoint("TOPLEFT", auraSlot, "BOTTOMLEFT", 0, -3)
	castSlot:SetPoint("TOPRIGHT", auraSlot, "BOTTOMRIGHT", 0, -3)
	castSlot:SetHeight(math.max(db.castHeight, spellSize))
	frame.castSlot = castSlot

	local castIcon = castSlot:CreateTexture(nil, "OVERLAY")
	castIcon:SetWidth(spellSize)
	castIcon:SetHeight(spellSize)
	castIcon:SetPoint("LEFT", castSlot, "LEFT", 0, 0)
	castIcon:Hide()
	frame.castIcon = castIcon

	local cast = CreateFrame("StatusBar", nil, castSlot)
	cast:SetStatusBarTexture(db.texture)
	cast:SetMinMaxValues(0, 1)
	cast:SetValue(0)
	cast:SetHeight(db.castHeight)
	cast:SetPoint("LEFT", castIcon, "RIGHT", 2, 0)
	cast:SetPoint("RIGHT", castSlot, "RIGHT", 0, 0)
	cast:SetStatusBarColor(unpack(db.colors.cast))
	cast:Hide()
	frame.cast = cast

	local castBg = cast:CreateTexture(nil, "BACKGROUND")
	castBg:SetAllPoints()
	castBg:SetTexture(db.texture)
	castBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

	local castText = cast:CreateFontString(nil, "OVERLAY")
	castText:SetFont(db.font, db.fontSize - 2, db.fontOutline)
	castText:SetPoint("CENTER", cast, "CENTER", 0, 0)
	castText:SetTextColor(1, 1, 1)
	frame.castText = castText

	EP.LayoutCastBar(frame, false)

	frame:EnableMouse(false)
	content:EnableMouse(false)
	return frame
end

function EP.ApplyStyle(visual)
	local db = EP.db
	if visual.content then
		visual.content:SetWidth(db.width)
		visual.content:SetHeight(db.height + 18)
	end
	if not visual.auras and visual.content and EP.CreateAuraBar then
		EP.CreateAuraBar(visual.content, visual)
	end
	visual.bg:SetHeight(db.height)
	visual.health:SetStatusBarTexture(db.texture)
	visual.bg:SetTexture(db.texture)
	visual.bg:SetVertexColor(unpack(db.colors.background))
	local function EnsureHealthFS(key)
		if not visual.health then
			return
		end
		if not visual[key] then
			local fs = visual.health:CreateFontString(nil, "OVERLAY")
			fs:SetTextColor(1, 1, 1)
			fs:SetShadowOffset(1, -1)
			visual[key] = fs
		elseif visual[key].GetParent and visual[key]:GetParent() ~= visual.health then
			-- Older builds parented to content (behind the bar) — bring back on top
			visual[key]:SetParent(visual.health)
			if visual[key].SetDrawLayer then
				visual[key]:SetDrawLayer("OVERLAY")
			end
		end
	end
	EnsureHealthFS("healthText")
	EnsureHealthFS("healthText2")
	local fontSize = EP.GetHealthTextFontSize(db)
	if visual.healthText then
		visual.healthText:SetFont(db.font, fontSize, db.fontOutline)
		EP.AnchorHealthText(visual.healthText, visual.health, db.healthTextAlign)
		if not db.showHealthText then
			visual.healthText:Hide()
		end
	end
	if visual.healthText2 then
		visual.healthText2:SetFont(db.font, fontSize, db.fontOutline)
		EP.AnchorHealthText(visual.healthText2, visual.health, db.healthTextAlign2)
		if not db.showHealthText then
			visual.healthText2:Hide()
		end
	end
	visual.name:SetFont(db.font, db.fontSize, db.fontOutline)
	visual.name:SetTextColor(unpack(db.colors.name))
	visual.level:SetFont(db.font, db.fontSize - 1, db.fontOutline)
	visual.level:SetTextColor(unpack(db.colors.level))
	if visual.threat then
		visual.threat:SetFont(db.font, db.fontSize - 1, db.fontOutline)
	end
	if visual.auraSlot then
		visual.auraSlot:SetHeight(EP.GetCastSpellIconSize(db))
	end
	if visual.castSlot and visual.auraSlot then
		visual.castSlot:ClearAllPoints()
		visual.castSlot:SetPoint("TOPLEFT", visual.auraSlot, "BOTTOMLEFT", 0, -3)
		visual.castSlot:SetPoint("TOPRIGHT", visual.auraSlot, "BOTTOMRIGHT", 0, -3)
	end
	visual.cast:SetStatusBarTexture(db.texture)
	visual.cast:SetStatusBarColor(unpack(db.colors.cast))
	visual.castText:SetFont(db.font, db.fontSize - 2, db.fontOutline)
	EP.LayoutCastBar(visual, visual.castIcon and visual.castIcon:IsShown())

	if visual.border then
		visual.border:SetBackdropBorderColor(unpack(db.colors.border))
	end
	if EP.ApplyAuraStyle then
		EP.ApplyAuraStyle(visual)
	end
end

function EP.RefreshAllVisuals()
	if not EP.plates then
		return
	end
	for _, plate in pairs(EP.plates) do
		if plate.visual then
			EP.ApplyStyle(plate.visual)
			if plate.blizz and plate.blizz:IsShown() then
				EP.UpdatePlate(plate)
			end
		end
	end
end
