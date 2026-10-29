EasyPlates = EasyPlates or {}
local EP = EasyPlates

local panel

local function GetColor(key)
	local c = EP.db.colors[key]
	return c[1], c[2], c[3], c[4] or 1
end

local function SetColor(key, r, g, b, a)
	local c = EP.db.colors[key]
	c[1], c[2], c[3] = r, g, b
	if a ~= nil then
		c[4] = a
	end
	if EP.RefreshAllVisuals then
		EP.RefreshAllVisuals()
	end
	if panel and panel.RefreshSwatches then
		panel:RefreshSwatches()
	end
end

local function OpenColorPicker(key, hasAlpha, swatch)
	local r, g, b, a = GetColor(key)

	ColorPickerFrame.func = function()
		local nr, ng, nb = ColorPickerFrame:GetColorRGB()
		local na = a
		if hasAlpha then
			na = 1 - OpacitySliderFrame:GetValue()
		end
		SetColor(key, nr, ng, nb, hasAlpha and na or nil)
		if swatch and swatch.Update then
			swatch:Update()
		end
	end

	ColorPickerFrame.opacityFunc = ColorPickerFrame.func

	ColorPickerFrame.cancelFunc = function(prev)
		SetColor(key, prev.r, prev.g, prev.b, hasAlpha and prev.a or nil)
		if swatch and swatch.Update then
			swatch:Update()
		end
	end

	ColorPickerFrame.hasOpacity = hasAlpha and true or false
	if hasAlpha then
		ColorPickerFrame.opacity = 1 - (a or 1)
	end

	ColorPickerFrame.previousValues = { r = r, g = g, b = b, a = a }
	ColorPickerFrame:SetColorRGB(r, g, b)
	ShowUIPanel(ColorPickerFrame)
end

local function CreateHeader(parent, text, x, y)
	local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetText(text)
	return fs
end

local function CreateColorSwatch(parent, label, key, hasAlpha, x, y)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetPoint("TOPLEFT", x, y)
	btn:SetWidth(24)
	btn:SetHeight(24)

	local border = btn:CreateTexture(nil, "BACKGROUND")
	border:SetAllPoints()
	border:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	border:SetVertexColor(0, 0, 0, 1)

	local tex = btn:CreateTexture(nil, "ARTWORK")
	tex:SetPoint("TOPLEFT", 2, -2)
	tex:SetPoint("BOTTOMRIGHT", -2, 2)
	tex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	btn.tex = tex

	local check = btn:CreateTexture(nil, "OVERLAY")
	check:SetTexture("Interface\\Buttons\\UI-ColorPicker-Buttons")
	check:SetTexCoord(0.25, 0.5, 0, 1)
	check:SetWidth(16)
	check:SetHeight(16)
	check:SetPoint("CENTER")
	check:Hide()
	btn.check = check

	local name = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	name:SetPoint("LEFT", btn, "RIGHT", 8, 0)
	name:SetText(label)

	function btn:Update()
		local r, g, b, a = GetColor(key)
		tex:SetVertexColor(r, g, b, hasAlpha and a or 1)
	end

	btn:SetScript("OnClick", function()
		OpenColorPicker(key, hasAlpha, btn)
	end)

	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(label, 1, 1, 1)
		GameTooltip:AddLine("Klicken, um die Farbe zu ändern.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	btn:Update()
	return btn
end

local function BuildPanel()
	panel = CreateFrame("Frame", "EasyPlatesOptionsPanel", UIParent)
	panel.name = "EasyPlates"
	panel:Hide()

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("EasyPlates")

	local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	sub:SetPoint("RIGHT", panel, "RIGHT", -32, 0)
	sub:SetJustifyH("LEFT")
	sub:SetText("Eigene Nameplates für Wrath of the Lich King 3.3.5a.\nFarben gelten sofort für alle sichtbaren Plates.")

	panel.swatches = {}

	-- Reaction / bar colors
	CreateHeader(panel, "Reaktionsfarben (Balken)", 16, -70)

	local barKeys = {
		{ key = "hostile",  label = "Feindlich",   hasAlpha = false },
		{ key = "neutral",  label = "Neutral",     hasAlpha = false },
		{ key = "friendly", label = "Freundlich",  hasAlpha = false },
		{ key = "tapped",   label = "Getappt",     hasAlpha = false },
		{ key = "cast",     label = "Zauberleiste", hasAlpha = false },
		{ key = "background", label = "Balkenhintergrund", hasAlpha = true },
		{ key = "border",   label = "Rahmen",      hasAlpha = true },
	}

	local y = -95
	for i, info in ipairs(barKeys) do
		local sw = CreateColorSwatch(panel, info.label, info.key, info.hasAlpha, 32, y)
		panel.swatches[#panel.swatches + 1] = sw
		y = y - 30
	end

	-- Overlay text + target colors
	CreateHeader(panel, "Overlay-Schrift", 260, -70)

	local textKeys = {
		{ key = "name",  label = "Name",  hasAlpha = false },
		{ key = "level", label = "Stufe", hasAlpha = false },
	}

	local ty = -95
	for i, info in ipairs(textKeys) do
		local sw = CreateColorSwatch(panel, info.label, info.key, info.hasAlpha, 276, ty)
		panel.swatches[#panel.swatches + 1] = sw
		ty = ty - 30
	end

	CreateHeader(panel, "Anvisiertes Ziel", 260, ty - 10)
	ty = ty - 35
	do
		local sw = CreateColorSwatch(panel, "Ziel-Rahmen", "targetBorder", true, 276, ty)
		panel.swatches[#panel.swatches + 1] = sw
	end

	ty = ty - 40
	CreateHeader(panel, "Anzeige", 260, ty)
	ty = ty - 28

	local function AddCheck(name, label, key, yOff)
		local check = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
		check:SetPoint("TOPLEFT", 276, yOff)
		_G[check:GetName() .. "Text"]:SetText(label)
		check:SetScript("OnClick", function(self)
			EP.db[key] = self:GetChecked() and true or false
			if EP.RefreshAllVisuals then
				EP.RefreshAllVisuals()
			end
		end)
		check:SetScript("OnShow", function(self)
			self:SetChecked(EP.db and EP.db[key])
		end)
		check:SetChecked(EP.db and EP.db[key])
		return check
	end

	panel.threatCheck = AddCheck("EasyPlatesShowThreatCheck", "Bedrohung in %", "showThreat", ty)
	ty = ty - 26
	panel.raidCheck = AddCheck("EasyPlatesShowRaidCheck", "Raid-Symbol", "showRaidIcon", ty)
	ty = ty - 26
	panel.aurasCheck = AddCheck("EasyPlatesShowAurasCheck", "Buffs / Debuffs", "showAuras", ty)
	ty = ty - 26
	panel.buffsCheck = AddCheck("EasyPlatesShowBuffsCheck", "Buffs anzeigen", "showBuffs", ty)
	ty = ty - 26
	panel.debuffsCheck = AddCheck("EasyPlatesShowDebuffsCheck", "Debuffs anzeigen", "showDebuffs", ty)

	-- Reset button (classic UI style)
	local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	reset:SetWidth(140)
	reset:SetHeight(22)
	reset:SetPoint("BOTTOMLEFT", 16, 16)
	reset:SetText("Zurücksetzen")
	reset:SetScript("OnClick", function()
		EasyPlatesDB = EP.CopyTable(EP.Defaults)
		EP.db = EasyPlatesDB
		if EP.RefreshAllVisuals then
			EP.RefreshAllVisuals()
		end
		panel:RefreshSwatches()
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EasyPlates|r: Farben zurückgesetzt.")
	end)

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("LEFT", reset, "RIGHT", 12, 0)
	hint:SetText("Esc · Interface · AddOns · EasyPlates")

	function panel:RefreshSwatches()
		for _, sw in ipairs(self.swatches) do
			sw:Update()
		end
	end

	panel.refresh = function(self)
		if EP.db then
			self:RefreshSwatches()
		end
	end

	panel.okay = function() end
	panel.cancel = function() end
	panel.default = function()
		EasyPlatesDB = EP.CopyTable(EP.Defaults)
		EP.db = EasyPlatesDB
		if EP.RefreshAllVisuals then
			EP.RefreshAllVisuals()
		end
		panel:RefreshSwatches()
	end

	InterfaceOptions_AddCategory(panel)
	EP.optionsPanel = panel
end

function EP.OpenOptions()
	if not panel then
		return
	end
	InterfaceOptionsFrame_OpenToCategory(panel)
	-- 3.3.5a: Kategorie manchmal erst beim zweiten Aufruf sichtbar
	InterfaceOptionsFrame_OpenToCategory(panel)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
	BuildPanel()
	self:UnregisterAllEvents()
end)
