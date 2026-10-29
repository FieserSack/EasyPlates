EasyPlates = EasyPlates or {}
local EP = EasyPlates

local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local UnitExists = UnitExists
local UnitCanAttack = UnitCanAttack

-- Buff/debuff icons match cast-spell icon size (castHeight + 2)
local function AuraIconSize()
	return EP.GetCastSpellIconSize and EP.GetCastSpellIconSize(EP.db) or 12
end

local BUFF_OFFSET_X = 3
local DEBUFF_OFFSET_X = 4

local DebuffTypeColor = DebuffTypeColor or {
	none = { r = 0.80, g = 0.00, b = 0.00 },
	Magic = { r = 0.20, g = 0.60, b = 1.00 },
	Curse = { r = 0.60, g = 0.00, b = 1.00 },
	Disease = { r = 0.60, g = 0.40, b = 0.00 },
	Poison = { r = 0.00, g = 0.60, b = 0.00 },
}

local function CreateAuraIcon(parent, isDebuff)
	local btn = CreateFrame("Frame", nil, parent)
	btn:Hide()
	btn.isDebuff = isDebuff and true or false

	local icon = btn:CreateTexture(nil, "BACKGROUND")
	icon:SetAllPoints(btn)
	btn.icon = icon

	-- TargetFrame debuff border (UI-Debuff-Overlays)
	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
	border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
	border:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
	border:Hide()
	btn.border = border

	-- TargetFrame stealable overlay
	local steal = btn:CreateTexture(nil, "OVERLAY")
	steal:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Stealable")
	steal:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
	steal:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -3)
	steal:SetBlendMode("ADD")
	steal:Hide()
	btn.stealable = steal

	-- Stack count: small, bottom-right (~1/4 of icon size)
	local count = btn:CreateFontString(nil, "OVERLAY")
	count:SetFont("Fonts\\FRIZQT__.TTF", 6, "OUTLINE")
	count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
	count:SetJustifyH("RIGHT")
	count:SetJustifyV("BOTTOM")
	count:SetShadowOffset(1, -1)
	count:SetTextColor(1, 1, 1)
	btn.count = count

	local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
	cd:SetAllPoints(icon)
	if cd.SetReverse then
		cd:SetReverse(true)
	end
	if cd.SetDrawEdge then
		cd:SetDrawEdge(false)
	end
	btn.cd = cd

	btn._tex = nil
	btn._count = nil
	btn._exp = nil
	btn._dur = nil
	btn._steal = nil
	btn._br = nil
	btn._bg = nil
	btn._bb = nil
	btn._x = nil
	btn._size = nil

	return btn
end

function EP.CreateAuraBar(parent, visual)
	local db = EP.db
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(AuraIconSize())
	bar:SetWidth(db.width or 120)

	-- Directly under health in reserved aura slot (cast bar is below this)
	if visual.auraSlot then
		bar:SetPoint("TOPLEFT", visual.auraSlot, "TOPLEFT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", visual.auraSlot, "BOTTOMRIGHT", 0, 0)
	elseif visual.bg then
		bar:SetPoint("TOPLEFT", visual.bg, "BOTTOMLEFT", 0, -2)
	end
	bar:Hide()

	-- Pool shared for buffs + debuffs (style applied per aura)
	bar.icons = {}
	local max = db.auraMax or 16
	for i = 1, max do
		bar.icons[i] = CreateAuraIcon(bar, false)
	end

	visual.auras = bar
	return bar
end

function EP.EnsureAuraIcons(bar, needed)
	local max = (EP.db and EP.db.auraMax) or 16
	needed = math.min(needed, max)
	while #bar.icons < needed do
		bar.icons[#bar.icons + 1] = CreateAuraIcon(bar, false)
	end
end

local function SetIconAura(btn, x, size, texture, count, duration, expiration, isDebuff, debuffType, isStealable)
	count = count or 0
	duration = duration or 0
	expiration = expiration or 0
	isStealable = isStealable and true or false

	local cooldownChanged = (btn._exp ~= expiration) or (btn._dur ~= duration) or (btn._tex ~= texture)

	if btn._x ~= x then
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", btn:GetParent(), "TOPLEFT", x, 0)
		btn._x = x
	end

	if btn._size ~= size then
		btn:SetWidth(size)
		btn:SetHeight(size)
		-- ~1/4 of icon size (min 6 for readability on tiny plate icons)
		local stackFont = math.max(6, math.floor(size * 0.25 + 0.5))
		btn.count:SetFont("Fonts\\FRIZQT__.TTF", stackFont, "OUTLINE")
		btn.count:ClearAllPoints()
		btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
		btn._size = size
	end

	if btn._tex ~= texture then
		btn.icon:SetTexture(texture)
		btn._tex = texture
	end

	if btn._count ~= count then
		if count > 1 then
			btn.count:SetText(tostring(count))
			btn.count:Show()
		else
			btn.count:SetText("")
			btn.count:Hide()
		end
		btn._count = count
	end

	-- Debuff type border (TargetFrame style); buffs have none
	if isDebuff then
		local color = DebuffTypeColor[debuffType or "none"] or DebuffTypeColor.none
		if btn._br ~= color.r or btn._bg ~= color.g or btn._bb ~= color.b then
			btn.border:SetVertexColor(color.r, color.g, color.b)
			btn._br, btn._bg, btn._bb = color.r, color.g, color.b
		end
		btn.border:Show()
	else
		btn.border:Hide()
		btn._br, btn._bg, btn._bb = nil, nil, nil
	end

	-- Stealable overlay only on buffs (TargetFrame: isStealable)
	if (not isDebuff) and isStealable then
		if btn._steal ~= true then
			btn.stealable:Show()
			btn._steal = true
		end
	else
		if btn._steal then
			btn.stealable:Hide()
			btn._steal = false
		end
	end

	if cooldownChanged then
		if duration > 0 and expiration > 0 then
			CooldownFrame_SetTimer(btn.cd, expiration - duration, duration, 1)
			btn.cd:Show()
		else
			btn.cd:Hide()
		end
		btn._exp = expiration
		btn._dur = duration
	end

	btn:Show()
end

local function HideTrailing(bar, fromIndex)
	for i = fromIndex, #bar.icons do
		local btn = bar.icons[i]
		if btn:IsShown() then
			btn:Hide()
			btn._tex = nil
			btn._count = nil
			btn._exp = nil
			btn._dur = nil
			btn._x = nil
			btn._size = nil
			btn._steal = nil
			btn._br = nil
			if btn.stealable then btn.stealable:Hide() end
			if btn.border then btn.border:Hide() end
		end
	end
end

function EP.UpdateAuraBar(visual, unit)
	local db = EP.db
	local bar = visual.auras
	if not bar then
		return
	end

	if not db.showAuras or not unit or not UnitExists(unit) then
		bar:Hide()
		HideTrailing(bar, 1)
		return
	end

	local max = db.auraMax or 16
	local showBuffs = db.showBuffs ~= false
	local showDebuffs = db.showDebuffs ~= false

	if visual.auraSlot then
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", visual.auraSlot, "TOPLEFT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", visual.auraSlot, "BOTTOMRIGHT", 0, 0)
		visual.auraSlot:SetHeight(AuraIconSize())
	end

	local slot = 1
	local x = 0
	local size = AuraIconSize()
	local rowHeight = size

	local function Place(texture, count, duration, expiration, caster, isDebuff, debuffType, isStealable)
		if slot > max then
			return false
		end
		local gap = isDebuff and DEBUFF_OFFSET_X or BUFF_OFFSET_X
		EP.EnsureAuraIcons(bar, slot)
		local btn = bar.icons[slot]
		SetIconAura(btn, x, size, texture, count, duration, expiration, isDebuff, debuffType, isStealable)
		x = x + size + gap
		if size > rowHeight then
			rowHeight = size
		end
		slot = slot + 1
		return true
	end

	-- Buffs (TargetFrame order / stealable handling)
	if showBuffs then
		local i = 1
		while slot <= max do
			local name, _, icon, count, _, duration, expiration, caster, isStealable = UnitBuff(unit, i)
			if not name then
				break
			end
			if icon then
				if not Place(icon, count, duration, expiration, caster, false, nil, isStealable) then
					break
				end
			end
			i = i + 1
		end
	end

	-- Debuffs (type-colored border like TargetFrame)
	if showDebuffs then
		local i = 1
		local isEnemy = UnitCanAttack("player", unit)
		while slot <= max do
			local name, _, icon, count, debuffType, duration, expiration, caster = UnitDebuff(unit, i)
			if not name then
				break
			end
			if icon then
				-- Match TargetFrame SHOW_CASTABLE_DEBUFFS filter when set
				local show = true
				if SHOW_CASTABLE_DEBUFFS == "1" and isEnemy then
					show = (caster == "player" or caster == "vehicle")
				end
				if show then
					if not Place(icon, count, duration, expiration, caster, true, debuffType, false) then
						break
					end
				end
			end
			i = i + 1
		end
	end

	HideTrailing(bar, slot)
	bar:SetHeight(rowHeight)

	if slot > 1 then
		bar:SetWidth(math.max(1, x - 1))
		bar:Show()
	else
		bar:Hide()
	end
end

function EP.ApplyAuraStyle(visual)
	local bar = visual.auras
	if not bar then
		return
	end
	local size = AuraIconSize()
	bar:SetHeight(size)
	if visual.auraSlot then
		visual.auraSlot:SetHeight(size)
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", visual.auraSlot, "TOPLEFT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", visual.auraSlot, "BOTTOMRIGHT", 0, 0)
	end
	for i = 1, #bar.icons do
		local btn = bar.icons[i]
		btn._exp = nil
		btn._dur = nil
		btn._size = nil
	end
end
