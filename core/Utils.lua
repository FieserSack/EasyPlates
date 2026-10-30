EasyPlates = EasyPlates or {}
local EP = EasyPlates

-- Same size for enemy cast-spell icon and plate buff/debuff icons
function EP.GetCastSpellIconSize(db)
	db = db or EP.db or {}
	return (db.castHeight or 10) + 2
end

-- Layout cast icon + bar across full plate width (icon left, bar fills rest)
function EP.LayoutCastBar(visual, showIcon)
	if not visual or not visual.cast or not visual.castSlot then
		return
	end
	local db = EP.db or {}
	local spellSize = EP.GetCastSpellIconSize(db)
	local slotH = math.max(db.castHeight or 10, spellSize)

	visual.castSlot:SetHeight(slotH)
	visual.cast:SetHeight(db.castHeight or 10)
	visual.castIcon:SetWidth(spellSize)
	visual.castIcon:SetHeight(spellSize)

	visual.castIcon:ClearAllPoints()
	visual.castIcon:SetPoint("LEFT", visual.castSlot, "LEFT", 0, 0)

	visual.cast:ClearAllPoints()
	if showIcon then
		visual.cast:SetPoint("LEFT", visual.castIcon, "RIGHT", 2, 0)
	else
		visual.cast:SetPoint("LEFT", visual.castSlot, "LEFT", 0, 0)
	end
	visual.cast:SetPoint("RIGHT", visual.castSlot, "RIGHT", 0, 0)
end

-- Raid icon: left of name+health, ~combined height, 10% smaller
function EP.GetRaidIconSize(db)
	db = db or EP.db or {}
	return ((db.height or 12) + (db.fontSize or 11) + 6) * 0.9
end

function EP.AnchorRaidIcon(raid, name, bg, db)
	if not raid or not bg then
		return
	end
	local size = EP.GetRaidIconSize(db)
	raid:ClearAllPoints()
	raid:SetWidth(size)
	raid:SetHeight(size)
	-- Vertically centered across name row + health bar
	local offsetY = ((db and db.fontSize) or 11) / 2 + 1
	raid:SetPoint("RIGHT", bg, "LEFT", -4, offsetY)
end

local function FullNumber(n)
	return tostring(math.floor((n or 0) + 0.5))
end

function EP.FormatHealthText(cur, maxV, fmt)
	fmt = fmt or "NONE"
	if not fmt or fmt == "NONE" then
		return ""
	end
	cur = cur or 0
	maxV = maxV or 0
	if fmt == "CURRENT" then
		return FullNumber(cur)
	elseif fmt == "CURRENT_MAX" then
		return FullNumber(cur) .. "/" .. FullNumber(maxV)
	end
	if maxV > 0 then
		return string.format("%.0f%%", (cur / maxV) * 100)
	end
	return "0%"
end

-- Secondary format options blocked by the primary selection
function EP.IsHealthFormatBlocked(primary, candidate)
	if not candidate or candidate == "NONE" then
		return false
	end
	if primary == "PERCENT" then
		return candidate == "PERCENT"
	end
	if primary == "CURRENT" or primary == "CURRENT_MAX" then
		return candidate == "CURRENT" or candidate == "CURRENT_MAX"
	end
	return false
end

function EP.ResolveHealthFormat2(db)
	if not db then
		return "NONE"
	end
	local f2 = db.healthTextFormat2 or "NONE"
	if EP.IsHealthFormatBlocked(db.healthTextFormat, f2) then
		db.healthTextFormat2 = "NONE"
		return "NONE"
	end
	return f2
end

function EP.IsHealthAlignBlocked(primary, candidate)
	return primary and candidate and primary == candidate
end

-- If secondary align matches primary, pick the next free side
function EP.ResolveHealthAlign2(db)
	if not db then
		return "RIGHT"
	end
	local a1 = db.healthTextAlign or "LEFT"
	local a2 = db.healthTextAlign2 or "RIGHT"
	if not EP.IsHealthAlignBlocked(a1, a2) then
		return a2
	end
	local order = { "LEFT", "CENTER", "RIGHT" }
	for i = 1, #order do
		if order[i] ~= a1 then
			db.healthTextAlign2 = order[i]
			return order[i]
		end
	end
	db.healthTextAlign2 = "RIGHT"
	return "RIGHT"
end

function EP.AnchorHealthText(fs, bar, align)
	if not fs or not bar then
		return
	end
	align = align or "CENTER"
	fs:ClearAllPoints()
	fs:SetJustifyH(align)
	fs:SetJustifyV("MIDDLE")
	-- Single mid-point anchor keeps the text vertically centered in the bar
	if align == "LEFT" then
		fs:SetPoint("LEFT", bar, "LEFT", 3, 0)
	elseif align == "RIGHT" then
		fs:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
	else
		fs:SetPoint("CENTER", bar, "CENTER", 0, 0)
	end
end

function EP.GetHealthTextFontSize(db)
	return math.max(7, (db and db.fontSize or 11) - 3)
end

function EP.CopyTable(src)
	if type(src) ~= "table" then
		return src
	end
	local dst = {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = EP.CopyTable(v)
		else
			dst[k] = v
		end
	end
	return dst
end

function EP.MergeDefaults(db, defaults)
	if type(db) ~= "table" then
		return EP.CopyTable(defaults)
	end
	for k, v in pairs(defaults) do
		if type(v) == "table" then
			db[k] = EP.MergeDefaults(db[k], v)
		elseif db[k] == nil then
			db[k] = v
		end
	end
	return db
end

function EP.SetStatusBarColor(bar, r, g, b, a)
	if bar and bar.SetStatusBarColor then
		bar:SetStatusBarColor(r, g, b, a or 1)
	end
end

local function ReactionKey(r, g, b)
	-- Blizzard default nameplate colors encode reaction
	if g > 0.9 and r > 0.9 and b < 0.2 then
		return "neutral"
	elseif r > 0.9 and g < 0.2 and b < 0.2 then
		return "hostile"
	elseif b > 0.9 and r < 0.2 and g < 0.2 then
		-- rare / special blue-ish defaults fall through
		return "hostile"
	elseif g > 0.9 and r < 0.2 and b < 0.2 then
		return "friendly"
	elseif r > 0.5 and g > 0.5 and b > 0.5 and r < 0.7 then
		return "tapped"
	end
	return nil
end

function EP.GetReactionColor(r, g, b, db)
	local key = ReactionKey(r, g, b)
	if key == "neutral" then
		return unpack(db.colors.neutral)
	elseif key == "hostile" then
		return unpack(db.colors.hostile)
	elseif key == "friendly" then
		return unpack(db.colors.friendly)
	elseif key == "tapped" then
		return unpack(db.colors.tapped)
	end
	return r, g, b
end

function EP.GetReactionTextColor(r, g, b, db)
	local key = ReactionKey(r, g, b)
	local c
	if key == "neutral" then
		c = db.colors.neutralText
	elseif key == "hostile" then
		c = db.colors.hostileText
	elseif key == "friendly" then
		c = db.colors.friendlyText
	else
		c = db.colors.name
	end
	if c then
		return unpack(c)
	end
	return 1, 1, 1
end
