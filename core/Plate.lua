EasyPlates = EasyPlates or {}
local EP = EasyPlates

local UnitExists = UnitExists
local UnitName = UnitName
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local GetThreatStatusColor = GetThreatStatusColor
local format = string.format

local function PlateName(plate)
	return plate.nameText and plate.nameText:GetText() or nil
end

local function IsCurrentTarget(plate)
	if not UnitExists("target") then
		return false
	end
	-- 3.3.5a: with a target selected, only the target plate keeps alpha == 1
	local blizz = plate.blizz
	if blizz.GetAlpha and blizz:GetAlpha() < 1 then
		return false
	end
	local plateName = PlateName(plate)
	local targetName = UnitName("target")
	if plateName and targetName and plateName == targetName then
		return true
	end
	-- Fallback when names collide or fontstring missing: full-alpha plate
	return blizz.GetAlpha and blizz:GetAlpha() == 1
end

-- Resolve a unit token for this plate (needed for threat % / auras on 3.3.5a)
function EP.GetPlateUnit(plate)
	local name = PlateName(plate)
	if not name then
		return nil
	end
	if IsCurrentTarget(plate) then
		return "target"
	end
	if UnitExists("mouseover") and UnitName("mouseover") == name then
		return "mouseover"
	end
	if UnitExists("focus") and UnitName("focus") == name then
		return "focus"
	end
	return nil
end

local function GetPlateUnit(plate)
	return EP.GetPlateUnit(plate)
end

local function UpdateHealth(plate)
	local db = EP.db
	local health = plate.health
	local visual = plate.visual
	if not health then
		return
	end

	local minV, maxV = health:GetMinMaxValues()
	local val = health:GetValue()
	if maxV and maxV > 0 then
		visual.health:SetMinMaxValues(minV, maxV)
		visual.health:SetValue(val)
	end

	local r, g, b = health:GetStatusBarColor()
	r, g, b = EP.GetReactionColor(r, g, b, db)
	visual.health:SetStatusBarColor(r, g, b)

	local function ApplyHealthFS(fs, fmt, align)
		if not fs then
			return
		end
		local show = db.showHealthText and fmt and fmt ~= "NONE"
		if show then
			fs:SetText(EP.FormatHealthText(val, maxV, fmt))
			EP.AnchorHealthText(fs, visual.health, align)
			fs:Show()
		else
			fs:SetText("")
			fs:Hide()
		end
	end
	ApplyHealthFS(visual.healthText, db.healthTextFormat, db.healthTextAlign)
	ApplyHealthFS(visual.healthText2, EP.ResolveHealthFormat2(db), EP.ResolveHealthAlign2(db))
end

local function UpdateIdentity(plate)
	local db = EP.db
	local visual = plate.visual

	if plate.nameText then
		visual.name:SetText(plate.nameText:GetText() or "")
	end
	visual.name:SetTextColor(unpack(db.colors.name))

	if db.showLevel and plate.levelText then
		local lvl = plate.levelText:GetText() or ""
		visual.level:SetText(lvl)
		visual.level:SetTextColor(unpack(db.colors.level))
		visual.level:Show()
	else
		visual.level:Hide()
	end

	-- Level right of bar; elite right of level
	visual.level:ClearAllPoints()
	visual.level:SetPoint("LEFT", visual.bg, "RIGHT", 4, 0)
	visual.elite:ClearAllPoints()
	if visual.level:IsShown() then
		visual.elite:SetPoint("LEFT", visual.level, "RIGHT", 3, 0)
	else
		visual.elite:SetPoint("LEFT", visual.bg, "RIGHT", 4, 0)
	end

	if db.showElite and plate.eliteIcon and plate.eliteIcon:IsShown() then
		local tex = plate.eliteIcon:GetTexture()
		if tex then
			visual.elite:SetTexture(tex)
			visual.elite:Show()
		else
			visual.elite:Hide()
		end
	else
		visual.elite:Hide()
	end

	-- Name stays above the bar (raid sits left of the whole name+bar block)
	visual.name:ClearAllPoints()
	visual.name:SetPoint("BOTTOMLEFT", visual.bg, "TOPLEFT", 0, 2)
	if visual.threat and visual.threat:IsShown() then
		visual.name:SetPoint("RIGHT", visual.threat, "LEFT", -4, 0)
	else
		visual.name:SetPoint("BOTTOMRIGHT", visual.bg, "TOPRIGHT", 0, 2)
	end

	-- Raid mark: always shown when Blizzard provides one
	local raid = plate.raidIcon or visual.raid
	if raid then
		EP.AnchorRaidIcon(raid, visual.name, visual.bg, db)
		raid:SetAlpha(1)
	end
end

local function UpdateCast(plate)
	local db = EP.db
	local visual = plate.visual
	local cast = plate.cast

	if not db.showCastbar or not cast or not cast:IsShown() then
		visual.cast:Hide()
		visual.castIcon:Hide()
		if EP.LayoutCastBar then
			EP.LayoutCastBar(visual, false)
		end
		return
	end

	local minV, maxV = cast:GetMinMaxValues()
	local val = cast:GetValue()
	visual.cast:SetMinMaxValues(minV, maxV)
	visual.cast:SetValue(val)
	visual.cast:SetStatusBarColor(unpack(db.colors.cast))
	visual.cast:Show()

	-- Spell icon from Blizzard cast icon region (same as default nameplate)
	local tex = plate.castIcon and plate.castIcon.GetTexture and plate.castIcon:GetTexture()
	local showIcon = tex and true or false
	if showIcon then
		visual.castIcon:SetTexture(tex)
		visual.castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		visual.castIcon:Show()
	else
		visual.castIcon:Hide()
	end

	-- Full plate width: icon left + bar fills the rest
	if EP.LayoutCastBar then
		EP.LayoutCastBar(visual, showIcon)
	end

	visual.castText:SetText("")
end

local function UpdateBorder(plate, isTarget)
	local visual = plate.visual
	if not visual.border then
		return
	end
	local db = EP.db
	if isTarget then
		visual.border:SetBackdropBorderColor(unpack(db.colors.targetBorder))
	else
		visual.border:SetBackdropBorderColor(unpack(db.colors.border))
	end
end

local function UpdateThreat(plate, isTarget)
	local db = EP.db
	local visual = plate.visual
	local fs = visual.threat
	if not fs then
		return
	end

	if not db.showThreat then
		fs:Hide()
		visual.name:SetPoint("BOTTOMRIGHT", visual.bg, "TOPRIGHT", 0, 2)
		return
	end

	visual.name:SetPoint("RIGHT", fs, "LEFT", -4, 0)

	local pct, status
	local unit = GetPlateUnit(plate)
	if unit then
		local isTanking, s, scaled = UnitDetailedThreatSituation("player", unit)
		status = s
		pct = scaled
		if isTanking and (not pct or pct < 100) then
			-- While tanking, show at least 100%
			pct = pct or 100
			if pct < 100 then
				pct = 100
			end
		end
	end

	if pct then
		fs:SetText(format("%.0f%%", pct))
		if status and GetThreatStatusColor then
			fs:SetTextColor(GetThreatStatusColor(status))
		else
			fs:SetTextColor(1, 1, 1)
		end
		fs:Show()
		return
	end

	-- No unit token: only show when this is the target and we have glow status
	if isTarget then
		local _, s, scaled = UnitDetailedThreatSituation("player", "target")
		if scaled then
			fs:SetText(format("%.0f%%", scaled))
			if s and GetThreatStatusColor then
				fs:SetTextColor(GetThreatStatusColor(s))
			else
				fs:SetTextColor(1, 1, 1)
			end
			fs:Show()
			return
		end
	end

	fs:SetText("")
	fs:Hide()
end

local function UpdatePosition(plate)
	local visual = plate.visual
	visual:SetAllPoints(plate.blizz)

	local isTarget = IsCurrentTarget(plate)
	local db = EP.db
	local scale = isTarget and db.scale.target or db.scale.normal
	local alpha = isTarget and db.alpha.target or db.alpha.nonTarget

	-- Scale the inner content so SetAllPoints on the root stays stable
	if visual.content then
		visual.content:SetScale(scale)
	else
		visual:SetScale(scale)
	end
	visual:SetAlpha(alpha)
	UpdateBorder(plate, isTarget)
	UpdateThreat(plate, isTarget)
	if EP.UpdateAuraBar then
		EP.UpdateAuraBar(plate.visual, GetPlateUnit(plate))
	end
end

function EP.UpdatePlate(plate)
	if not plate or not plate.blizz or not plate.blizz:IsShown() then
		if plate and plate.visual then
			plate.visual:Hide()
		end
		return
	end

	-- Re-clear overlays if the client restored the threat texture this frame
	if EP.KillBlizzardOverlays then
		EP.KillBlizzardOverlays(plate)
	end
	UpdateHealth(plate)
	UpdateIdentity(plate)
	UpdateCast(plate)
	UpdatePosition(plate)
	plate.visual:Show()
end
