EasyPlates = EasyPlates or {}
local EP = EasyPlates

local WorldFrame = WorldFrame
local select = select
local pairs = pairs
local tostring = tostring
local strfind = string.find
local format = string.format
local _G = _G

-- Canonical 3.3.5a nameplate marker (ElvUI / TidyPlates method)
local OVERLAY = "Interface\\TargetingFrame\\UI-TargetingFrame-Flash"

EP.plates = EP.plates or {}
EP.active = EP.active or {}

local known = {}
local lastChildCount = 0

if not wipe then
	function wipe(t)
		for k in pairs(t) do
			t[k] = nil
		end
		return t
	end
end

local function IsNamePlateFrame(frame)
	if not frame or known[frame] then
		return false
	end

	-- Method 1: threat-flash overlay texture (most reliable on 3.3.5a)
	local region = frame.GetRegions and frame:GetRegions()
	if region and region.GetObjectType and region:GetObjectType() == "Texture" then
		local tex = region.GetTexture and region:GetTexture()
		if tex == OVERLAY then
			return true
		end
	end

	-- Method 2: global name NamePlateN
	local name = frame.GetName and frame:GetName()
	if name and strfind(name, "^NamePlate%d+$") then
		return true
	end

	return false
end

local function HideRegion(object)
	if not object then
		return
	end
	local objectType = object:GetObjectType()
	if objectType == "Texture" then
		object:SetTexture("")
		object:SetTexCoord(0, 0, 0, 0)
	elseif objectType == "FontString" then
		object:SetWidth(0.001)
	elseif objectType == "StatusBar" then
		object:SetStatusBarTexture("")
	end
	object:Hide()
end

-- Disable decorative texture by stripping the path (no Show/Hide fight = no blink).
-- Client may Show() it on aggro; without a texture it draws nothing.
local function KillTexture(tex)
	if not tex or not tex.SetTexture then
		return
	end
	local path = tex.GetTexture and tex:GetTexture()
	if path and path ~= "" then
		tex:SetTexture("")
		tex:SetTexCoord(0, 0, 0, 0)
		tex:SetVertexColor(0, 0, 0, 0)
	end
end

function EP.KillBlizzardOverlays(plate)
	if not plate then
		return
	end
	KillTexture(plate.threat)
	KillTexture(plate.border)
	KillTexture(plate.highlight)
	-- Never touch plate.raidIcon here — Blizzard Show/Hide drives the mark
	-- castIcon: keep texture path for reading, only force invisible
	if plate.castIcon and plate.castIcon.GetAlpha and plate.castIcon:GetAlpha() ~= 0 then
		plate.castIcon:SetAlpha(0)
	end
end

-- Reliable raid-mark detection (region order can differ on private servers)
local function FindRaidIconRegion(frame)
	local regions = { frame:GetRegions() }
	for i = 1, #regions do
		local region = regions[i]
		if region and region.GetObjectType and region:GetObjectType() == "Texture" and region.GetTexture then
			local tex = region:GetTexture()
			if tex then
				local path = tostring(tex)
				if strfind(path, "RaidTargetingIcon") or strfind(path, "UI%-RaidTargetingIcons") then
					return region
				end
			end
		end
	end
	return nil
end

local function AttachRaidIcon(plate, visual, raidIcon)
	if not raidIcon or not visual or not visual.content then
		return
	end
	-- Use Blizzard's own texture so Show/Hide + TexCoord stay correct
	raidIcon:SetParent(visual.content)
	if raidIcon.SetDrawLayer then
		raidIcon:SetDrawLayer("OVERLAY")
	end
	-- Final size/anchors are applied in UpdateIdentity via EP.AnchorRaidIcon
	raidIcon:ClearAllPoints()
	EP.AnchorRaidIcon(raidIcon, visual.name, visual.bg, EP.db)
	raidIcon:SetAlpha(1)
	raidIcon:SetVertexColor(1, 1, 1, 1)
	-- Drop placeholder if we created one
	if visual.raid and visual.raid ~= raidIcon then
		visual.raid:Hide()
	end
	visual.raid = raidIcon
	plate.raidIcon = raidIcon
	plate.raidAttached = true
end

local function HookPlateScripts(blizz, plate)
	if plate.hooked then
		return
	end
	plate.hooked = true

	blizz:HookScript("OnShow", function()
		if EP.UpdatePlate then
			EP.UpdatePlate(plate)
		end
	end)

	blizz:HookScript("OnHide", function()
		if plate.visual then
			plate.visual:Hide()
		end
	end)

	if plate.health then
		plate.health:HookScript("OnValueChanged", function()
			if blizz:IsShown() and EP.UpdatePlate then
				EP.UpdatePlate(plate)
			end
		end)
	end
end

function EP.RegisterPlate(blizz)
	if known[blizz] then
		return known[blizz]
	end

	-- 3.3.5a Blizzard layout:
	-- children: Health, CastBar
	-- regions: Threat, Border, CastBarBorder, CastBarShield, CastBarIcon,
	--          Highlight, Name, Level, BossIcon, RaidIcon, EliteIcon
	local health, cast = blizz:GetChildren()
	local threat, border, castBorder, castShield, castIcon, highlight, nameText, levelText, bossIcon, raidIcon, eliteIcon = blizz:GetRegions()

	-- Prefer texture-path match; positional GetRegions can be wrong on custom clients
	raidIcon = FindRaidIconRegion(blizz) or raidIcon

	if not health or not health.GetObjectType or health:GetObjectType() ~= "StatusBar" then
		health, cast = nil, nil
		local children = { blizz:GetChildren() }
		for i = 1, #children do
			local child = children[i]
			if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
				if not health then
					health = child
				elseif not cast then
					cast = child
					break
				end
			end
		end
	end

	if not health then
		return nil
	end

	-- Hide default artwork; keep Health/Cast StatusBars shown (value + IsShown needed)
	-- Threat/Border/Highlight: kill texture permanently (avoids red-glow blink from alpha fights)
	-- CastIcon: keep texture, fully transparent (GetTexture for our spell icon)
	-- RaidIcon: do NOT alpha-kill — reparented onto our visual below
	if threat then
		threat:SetTexture("")
		threat:SetTexCoord(0, 0, 0, 0)
		threat:SetVertexColor(0, 0, 0, 0)
	end
	if border then
		border:SetTexture("")
		border:SetTexCoord(0, 0, 0, 0)
		border:SetVertexColor(0, 0, 0, 0)
	end
	if highlight then
		highlight:SetTexture("")
		highlight:SetTexCoord(0, 0, 0, 0)
		highlight:SetVertexColor(0, 0, 0, 0)
	end
	if castIcon then
		castIcon:SetAlpha(0)
	end
	HideRegion(castBorder)
	HideRegion(castShield)
	HideRegion(nameText)
	HideRegion(levelText)
	if bossIcon then bossIcon:SetAlpha(0) end
	if eliteIcon then eliteIcon:SetAlpha(0) end

	health:SetStatusBarTexture("")
	local healthRegions = { health:GetRegions() }
	for i = 1, #healthRegions do
		local r = healthRegions[i]
		if r and r.GetObjectType and r:GetObjectType() == "Texture" then
			r:SetTexture("")
			r:SetTexCoord(0, 0, 0, 0)
		end
	end

	if cast then
		cast:SetStatusBarTexture("")
		local castRegions = { cast:GetRegions() }
		for i = 1, #castRegions do
			local r = castRegions[i]
			if r and r.GetObjectType and r:GetObjectType() == "Texture" then
				r:SetTexture("")
				r:SetTexCoord(0, 0, 0, 0)
			end
		end
	end

	local visual = EP.CreateVisual(blizz)
	visual:SetAllPoints(blizz)

	local plate = {
		blizz = blizz,
		health = health,
		cast = cast,
		threat = threat,
		border = border,
		highlight = highlight,
		nameText = nameText,
		levelText = levelText,
		eliteIcon = eliteIcon,
		raidIcon = raidIcon,
		castIcon = castIcon,
		visual = visual,
	}

	AttachRaidIcon(plate, visual, raidIcon)

	known[blizz] = plate
	EP.plates[blizz] = plate
	HookPlateScripts(blizz, plate)

	if blizz:IsShown() then
		EP.UpdatePlate(plate)
	end

	return plate
end

local function TryRegister(frame)
	if frame and not known[frame] and IsNamePlateFrame(frame) then
		EP.RegisterPlate(frame)
	end
end

-- Scan only newly added WorldFrame children (cheap + correct for 3.3.5a)
local function ScanNewChildren(...)
	local num = select("#", ...)
	for i = lastChildCount + 1, num do
		TryRegister(select(i, ...))
	end
end

-- Fallback: walk NamePlate1..40 globals (private servers / early creation)
local function ScanByGlobalName()
	for i = 1, 40 do
		local frame = _G["NamePlate" .. i]
		if frame then
			TryRegister(frame)
		end
	end
end

function EP.ScanNameplates(force)
	local count = WorldFrame:GetNumChildren()
	if force or count ~= lastChildCount then
		if count > lastChildCount then
			ScanNewChildren(WorldFrame:GetChildren())
		elseif force then
			-- Full pass when forced (e.g. /ep scan)
			local children = { WorldFrame:GetChildren() }
			for i = 1, #children do
				TryRegister(children[i])
			end
		end
		lastChildCount = count
	end

	ScanByGlobalName()
end

function EP.UpdateActivePlates()
	-- New WorldFrame children + NamePlate globals (retries until registered)
	local count = WorldFrame:GetNumChildren()
	if count ~= lastChildCount then
		EP.ScanNameplates()
	else
		ScanByGlobalName()
	end

	wipe(EP.active)

	for blizz, plate in pairs(EP.plates) do
		if blizz:IsShown() then
			EP.active[blizz] = plate
			EP.UpdatePlate(plate)
		elseif plate.visual and plate.visual:IsShown() then
			plate.visual:Hide()
		end
	end
end
