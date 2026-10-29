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

function EP.GetReactionColor(r, g, b, db)
	-- Blizzard default nameplate colors encode reaction
	if g > 0.9 and r > 0.9 and b < 0.2 then
		return unpack(db.colors.neutral)
	elseif r > 0.9 and g < 0.2 and b < 0.2 then
		return unpack(db.colors.hostile)
	elseif b > 0.9 and r < 0.2 and g < 0.2 then
		-- rare / special blue-ish defaults fall through
		return unpack(db.colors.hostile)
	elseif g > 0.9 and r < 0.2 and b < 0.2 then
		return unpack(db.colors.friendly)
	elseif r > 0.5 and g > 0.5 and b > 0.5 and r < 0.7 then
		return unpack(db.colors.tapped)
	end
	return r, g, b
end
