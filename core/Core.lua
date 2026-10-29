EasyPlates = EasyPlates or {}
local EP = EasyPlates

local ADDON_NAME = "EasyPlates"
local UPDATE_INTERVAL = 0.05

local elapsedUpdate = 0
local driver

local function OnUpdate(_, elapsed)
	-- Child-count scan runs inside UpdateActivePlates (cheap)
	elapsedUpdate = elapsedUpdate + elapsed
	if elapsedUpdate >= UPDATE_INTERVAL then
		elapsedUpdate = 0
		EP.UpdateActivePlates()
	end
end

local function EnableNameplates()
	-- 3.3.5a API: enemy nameplates (player can still toggle via keybind V)
	if ShowNamePlates then
		ShowNamePlates()
	end
end

local function InitDB()
	-- Migration from previous addon name
	if not EasyPlatesDB and PlatesPlusDB then
		EasyPlatesDB = PlatesPlusDB
	end
	EasyPlatesDB = EP.MergeDefaults(EasyPlatesDB, EP.Defaults)
	EP.db = EasyPlatesDB
	-- Fixed defaults (no longer configurable in options)
	EP.db.colors.tapped = EP.CopyTable(EP.Defaults.colors.tapped)
	EP.db.colors.cast = EP.CopyTable(EP.Defaults.colors.cast)
	-- Primary health format has no "Keine"; migrate older NONE value
	if not EP.db.healthTextFormat or EP.db.healthTextFormat == "NONE" then
		EP.db.healthTextFormat = EP.Defaults.healthTextFormat
	end
	if EP.db.healthTextFormat2 == nil then
		EP.db.healthTextFormat2 = EP.Defaults.healthTextFormat2
	end
	if EP.db.healthTextAlign2 == nil then
		EP.db.healthTextAlign2 = EP.Defaults.healthTextAlign2
	end
	EP.ResolveHealthFormat2(EP.db)
	EP.ResolveHealthAlign2(EP.db)
	-- Once: sync buff/debuff size to cast-spell icon (castHeight + 2)
	if not EP.db._auraMatchCastIcon then
		EP.db.auraSize = EP.GetCastSpellIconSize(EP.db)
		EP.db.auraSpacing = 3
		if (EP.db.auraMax or 0) < 16 then
			EP.db.auraMax = 16
		end
		EP.db._auraMatchCastIcon = true
	end
end

local function OnEvent(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		InitDB()
	elseif event == "PLAYER_LOGIN" then
		InitDB()
		EnableNameplates()

		driver = CreateFrame("Frame")
		driver:SetScript("OnUpdate", OnUpdate)

		EP.ScanNameplates()
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EasyPlates|r geladen (3.3.5a).")
	elseif event == "PLAYER_TARGET_CHANGED"
		or event == "UPDATE_MOUSEOVER_UNIT"
		or event == "PLAYER_FOCUS_CHANGED"
		or event == "UNIT_THREAT_LIST_UPDATE"
		or event == "UNIT_THREAT_SITUATION_UPDATE"
		or event == "UNIT_AURA" then
		EP.UpdateActivePlates()
	elseif event == "PLAYER_LOGOUT" then
		-- SavedVariables are written automatically
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", OnEvent)

-- Slash commands
SLASH_EASYPLATES1 = "/easyplates"
SLASH_EASYPLATES2 = "/ep"
SlashCmdList["EASYPLATES"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")

	if msg == "" or msg == "config" or msg == "options" then
		if EP.OpenOptions then
			EP.OpenOptions()
		end
		return
	end

	if msg == "reset" then
		EasyPlatesDB = EP.CopyTable(EP.Defaults)
		EP.db = EasyPlatesDB
		EP.RefreshAllVisuals()
		if EP.optionsPanel and EP.optionsPanel.RefreshSwatches then
			EP.optionsPanel:RefreshSwatches()
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EasyPlates|r: Einstellungen zurückgesetzt.")
		return
	end

	if msg == "scan" then
		EP.ScanNameplates(true)
		local n = 0
		local shown = 0
		for blizz, plate in pairs(EP.plates) do
			n = n + 1
			if blizz:IsShown() then
				shown = shown + 1
				EP.UpdatePlate(plate)
			end
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EasyPlates|r: " .. n .. " registriert, " .. shown .. " sichtbar.")
		return
	end

	if msg == "debug" then
		local count = WorldFrame:GetNumChildren()
		local named = 0
		local flash = 0
		local children = { WorldFrame:GetChildren() }
		for i = 1, #children do
			local f = children[i]
			local name = f.GetName and f:GetName()
			if name and name:find("^NamePlate%d") then
				named = named + 1
			end
			local region = f.GetRegions and f:GetRegions()
			if region and region.GetTexture and region:GetTexture() == "Interface\\TargetingFrame\\UI-TargetingFrame-Flash" then
				flash = flash + 1
			end
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EasyPlates|r Debug:")
		DEFAULT_CHAT_FRAME:AddMessage("  WorldFrame Kinder: " .. count)
		DEFAULT_CHAT_FRAME:AddMessage("  NamePlate*: " .. named)
		DEFAULT_CHAT_FRAME:AddMessage("  Flash-Textur: " .. flash)
		DEFAULT_CHAT_FRAME:AddMessage("  Registriert: " .. (function()
			local n = 0
			for _ in pairs(EP.plates) do n = n + 1 end
			return n
		end)())
		return
	end

	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EasyPlates|r Befehle:")
	DEFAULT_CHAT_FRAME:AddMessage("  /ep          - Optionen öffnen")
	DEFAULT_CHAT_FRAME:AddMessage("  /ep reset    - Standardwerte wiederherstellen")
	DEFAULT_CHAT_FRAME:AddMessage("  /ep scan     - Nameplates neu scannen")
	DEFAULT_CHAT_FRAME:AddMessage("  /ep debug    - Erkennungs-Diagnose")
end
