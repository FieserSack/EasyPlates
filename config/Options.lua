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

local function CreateColorSwatch(parent, label, key, hasAlpha, x, y, opts)
	opts = opts or {}
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

	if not opts.noLabel then
		local name = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		name:SetPoint("LEFT", btn, "RIGHT", 8, 0)
		name:SetText(label)
		btn.label = name
	end

	local tip = opts.tooltip or label

	function btn:Update()
		local r, g, b, a = GetColor(key)
		tex:SetVertexColor(r, g, b, hasAlpha and a or 1)
	end

	btn:SetScript("OnClick", function()
		OpenColorPicker(key, hasAlpha, btn)
	end)

	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(tip, 1, 1, 1)
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

	local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	version:SetPoint("LEFT", title, "RIGHT", 8, 0)
	version:SetText("v. " .. (EP.VERSION or "0.1"))

	panel.swatches = {}

	-- Reaction / bar + text colors
	CreateHeader(panel, "Reaktionsfarben (Balken/Text)", 16, -48)

	local barKeys = {
		{ key = "hostile",  label = "Feindlich",   hasAlpha = false, textKey = "hostileText" },
		{ key = "neutral",  label = "Neutral",     hasAlpha = false, textKey = "neutralText" },
		{ key = "friendly", label = "Freundlich",  hasAlpha = false, textKey = "friendlyText" },
		{ key = "background", label = "Balkenhintergrund", hasAlpha = true },
		{ key = "border",   label = "Rahmen",      hasAlpha = true },
	}

	local function AddCheck(name, label, key, yOff, opts)
		opts = opts or {}
		local x = opts.x or 276
		local check = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
		check:SetPoint("TOPLEFT", x, yOff)
		if opts.small then
			check:SetWidth(24)
			check:SetHeight(24)
		end
		local text = _G[check:GetName() .. "Text"]
		text:SetText(label)
		if opts.small then
			text:SetFontObject(GameFontHighlightSmall)
			text:ClearAllPoints()
			text:SetPoint("LEFT", check, "RIGHT", 0, 1)
		end
		check.dbKey = key
		check:SetScript("OnClick", function(self)
			EP.db[key] = self:GetChecked() and true or false
			if self.onToggle then
				self:onToggle()
			end
			if EP.RefreshAllVisuals then
				EP.RefreshAllVisuals()
			end
		end)
		check:SetScript("OnShow", function(self)
			self:SetChecked(EP.db and EP.db[key])
			if self.onShowExtra then
				self:onShowExtra()
			end
		end)
		check:SetChecked(EP.db and EP.db[key])
		return check
	end

	local y = -73
	for i, info in ipairs(barKeys) do
		if info.textKey then
			local sw = CreateColorSwatch(panel, info.label, info.key, info.hasAlpha, 32, y, {
				noLabel = true,
				tooltip = info.label .. " – Balken",
			})
			panel.swatches[#panel.swatches + 1] = sw

			local sep = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			sep:SetPoint("LEFT", sw, "RIGHT", 4, 0)
			sep:SetText(" / ")

			local tsw = CreateColorSwatch(panel, info.label, info.textKey, false, 32, y, {
				noLabel = true,
				tooltip = info.label .. " – Schriftfarbe",
			})
			tsw:ClearAllPoints()
			tsw:SetPoint("LEFT", sep, "RIGHT", 4, 0)
			panel.swatches[#panel.swatches + 1] = tsw

			local name = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			name:SetPoint("LEFT", tsw, "RIGHT", 8, 0)
			name:SetText(info.label)
		else
			local sw = CreateColorSwatch(panel, info.label, info.key, info.hasAlpha, 32, y)
			panel.swatches[#panel.swatches + 1] = sw
		end
		y = y - 30
	end

	-- Anzeige (left column, under reaction colors)
	-- Lebensanzeige + Bedrohung; Buffs/Debuffs remain right column
	y = y - 14
	CreateHeader(panel, "Anzeige", 16, y)
	y = y - 24
	-- 1. Format + Align   2. Format2 (Keine…) + Align2
	local alignChoices = {
		{ value = "LEFT", text = "Links" },
		{ value = "CENTER", text = "Mitte" },
		{ value = "RIGHT", text = "Rechts" },
	}
	local formatChoices1 = {
		{ value = "CURRENT", text = "Leben" },
		{ value = "CURRENT_MAX", text = "Leben/max" },
		{ value = "PERCENT", text = "Prozent" },
	}
	local formatChoices2 = {
		{ value = "NONE", text = "Keine" },
		{ value = "CURRENT", text = "Leben" },
		{ value = "CURRENT_MAX", text = "Leben/max" },
		{ value = "PERCENT", text = "Prozent" },
	}

	local function ChoiceLabel(list, value)
		for i = 1, #list do
			if list[i].value == value then
				return list[i].text
			end
		end
		return value
	end

	local function MakeChooser(name, key, choices, x, yOff, width, opts)
		opts = opts or {}
		local drop = CreateFrame("Frame", name, panel, "UIDropDownMenuTemplate")
		drop:SetPoint("TOPLEFT", x, yOff)
		UIDropDownMenu_SetWidth(drop, width or 90)
		UIDropDownMenu_JustifyText(drop, "LEFT")
		drop.dbKey = key
		drop.choices = choices
		drop.isDisabledOption = opts.isDisabledOption
		drop.onChanged = opts.onChanged

		local function Refresh()
			local cur = EP.db and EP.db[key]
			UIDropDownMenu_SetSelectedValue(drop, cur)
			UIDropDownMenu_SetText(drop, ChoiceLabel(choices, cur))
		end
		drop.Refresh = Refresh

		UIDropDownMenu_Initialize(drop, function()
			for i = 1, #choices do
				local c = choices[i]
				local info = UIDropDownMenu_CreateInfo()
				info.text = c.text
				info.value = c.value
				info.checked = EP.db and EP.db[key] == c.value
				if drop.isDisabledOption and drop.isDisabledOption(c.value) then
					info.disabled = true
				end
				info.func = function()
					EP.db[key] = c.value
					if drop.onChanged then
						drop.onChanged(c.value)
					end
					Refresh()
					if EP.RefreshAllVisuals then
						EP.RefreshAllVisuals()
					end
				end
				UIDropDownMenu_AddButton(info)
			end
		end)
		Refresh()
		return drop
	end

	local function SetDropEnabled(drop, enabled)
		if not drop then
			return
		end
		drop:Refresh()
		if enabled then
			UIDropDownMenu_EnableDropDown(drop)
		else
			UIDropDownMenu_DisableDropDown(drop)
		end
	end

	local function SyncHealthChoosers()
		local enabled = EP.db and EP.db.showHealthText
		if panel.healthTextCheck then
			panel.healthTextCheck:SetChecked(enabled)
		end
		if EP.db then
			EP.ResolveHealthFormat2(EP.db)
			EP.ResolveHealthAlign2(EP.db)
		end
		local labelFont = enabled and GameFontNormalSmall or GameFontDisableSmall
		if panel.healthRow1Label then
			panel.healthRow1Label:SetFontObject(labelFont)
		end
		if panel.healthRow2Label then
			panel.healthRow2Label:SetFontObject(labelFont)
		end
		SetDropEnabled(panel.healthFormatDrop, enabled)
		SetDropEnabled(panel.healthAlignDrop, enabled)
		SetDropEnabled(panel.healthFormat2Drop, enabled)
		SetDropEnabled(panel.healthAlign2Drop, enabled)
	end

	local healthCheckY = y
	panel.healthTextCheck = AddCheck("EasyPlatesShowHealthTextCheck", "Lebensanzeige", "showHealthText", y, { x = 16 })
	panel.healthTextCheck.onToggle = SyncHealthChoosers
	panel.healthTextCheck.onShowExtra = SyncHealthChoosers

	local function OnPrimaryFormatChanged()
		if EP.db then
			EP.ResolveHealthFormat2(EP.db)
		end
		if panel.healthFormat2Drop then
			panel.healthFormat2Drop:Refresh()
		end
	end

	local function OnPrimaryAlignChanged()
		if EP.db then
			EP.ResolveHealthAlign2(EP.db)
		end
		if panel.healthAlign2Drop then
			panel.healthAlign2Drop:Refresh()
		end
	end

	-- 1. Format + Align
	y = y - 26
	panel.healthRow1Label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	panel.healthRow1Label:SetPoint("TOPLEFT", 32, y - 6)
	panel.healthRow1Label:SetText("1.")
	panel.healthFormatDrop = MakeChooser(
		"EasyPlatesHealthFormatDropDown",
		"healthTextFormat",
		formatChoices1,
		40,
		y,
		100,
		{ onChanged = OnPrimaryFormatChanged }
	)
	panel.healthAlignDrop = MakeChooser(
		"EasyPlatesHealthAlignDropDown",
		"healthTextAlign",
		alignChoices,
		148,
		y,
		88,
		{ onChanged = OnPrimaryAlignChanged }
	)

	-- 2. Format2 (Keine…) + Align2 — gewählte Optionen aus Zeile 1 sind gesperrt
	y = y - 28
	panel.healthRow2Label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	panel.healthRow2Label:SetPoint("TOPLEFT", 32, y - 6)
	panel.healthRow2Label:SetText("2.")
	panel.healthFormat2Drop = MakeChooser(
		"EasyPlatesHealthFormat2DropDown",
		"healthTextFormat2",
		formatChoices2,
		40,
		y,
		100,
		{
			isDisabledOption = function(value)
				return EP.db and EP.IsHealthFormatBlocked(EP.db.healthTextFormat, value)
			end,
		}
	)
	panel.healthAlign2Drop = MakeChooser(
		"EasyPlatesHealthAlign2DropDown",
		"healthTextAlign2",
		alignChoices,
		148,
		y,
		88,
		{
			isDisabledOption = function(value)
				return EP.db and EP.IsHealthAlignBlocked(EP.db.healthTextAlign, value)
			end,
		}
	)
	SyncHealthChoosers()

	y = y - 30
	panel.threatCheck = AddCheck("EasyPlatesShowThreatCheck", "Bedrohung in %", "showThreat", y, { x = 16 })

	-- Overlay text + target colors
	CreateHeader(panel, "Overlay-Schrift", 260, -48)

	local textKeys = {
		{ key = "name",  label = "Name",  hasAlpha = false },
		{ key = "level", label = "Stufe", hasAlpha = false },
	}

	local ty = -73
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

	-- Mana: color + enable (plate bar wired later)
	ty = ty - 30
	do
		local sw = CreateColorSwatch(panel, "Mana", "mana", false, 276, ty, {
			noLabel = true,
			tooltip = "Mana",
		})
		panel.swatches[#panel.swatches + 1] = sw
		panel.manaCheck = AddCheck("EasyPlatesShowManaCheck", "Mana", "showMana", ty - 2, {
			x = 308,
		})
	end

	-- Buffs / Debuffs: same height as Lebensanzeige under Anzeige
	local function SyncAuraChildChecks()
		local enabled = EP.db and EP.db.showAuras
		if panel.buffsCheck then
			panel.buffsCheck:SetChecked(EP.db and EP.db.showBuffs)
			if enabled then
				panel.buffsCheck:Enable()
				_G[panel.buffsCheck:GetName() .. "Text"]:SetFontObject(GameFontHighlightSmall)
			else
				panel.buffsCheck:Disable()
				_G[panel.buffsCheck:GetName() .. "Text"]:SetFontObject(GameFontDisableSmall)
			end
		end
		if panel.debuffsCheck then
			panel.debuffsCheck:SetChecked(EP.db and EP.db.showDebuffs)
			if enabled then
				panel.debuffsCheck:Enable()
				_G[panel.debuffsCheck:GetName() .. "Text"]:SetFontObject(GameFontHighlightSmall)
			else
				panel.debuffsCheck:Disable()
				_G[panel.debuffsCheck:GetName() .. "Text"]:SetFontObject(GameFontDisableSmall)
			end
		end
	end

	local ay = healthCheckY
	panel.aurasCheck = AddCheck("EasyPlatesShowAurasCheck", "Buffs / Debuffs", "showAuras", ay)
	panel.aurasCheck.onToggle = SyncAuraChildChecks
	panel.aurasCheck.onShowExtra = SyncAuraChildChecks
	ay = ay - 22
	panel.buffsCheck = AddCheck("EasyPlatesShowBuffsCheck", "Buffs", "showBuffs", ay, {
		x = 300,
		small = true,
	})
	ay = ay - 20
	panel.debuffsCheck = AddCheck("EasyPlatesShowDebuffsCheck", "Debuffs", "showDebuffs", ay, {
		x = 300,
		small = true,
	})
	SyncAuraChildChecks()

	-- Reset button (classic UI style)
	local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	reset:SetWidth(140)
	reset:SetHeight(22)
	reset:SetPoint("BOTTOMRIGHT", -16, 16)
	reset:SetText("Zurücksetzen")
	reset:SetScript("OnClick", function()
		EasyPlatesDB = EP.CopyTable(EP.Defaults)
		EP.db = EasyPlatesDB
		if EP.RefreshAllVisuals then
			EP.RefreshAllVisuals()
		end
		panel:RefreshSwatches()
		panel.threatCheck:SetChecked(EP.db.showThreat)
		if panel.manaCheck then
			panel.manaCheck:SetChecked(EP.db.showMana)
		end
		panel.aurasCheck:SetChecked(EP.db.showAuras)
		SyncAuraChildChecks()
		SyncHealthChoosers()
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EasyPlates|r: Einstellungen zurückgesetzt.")
	end)

	function panel:RefreshSwatches()
		for _, sw in ipairs(self.swatches) do
			sw:Update()
		end
	end

	panel.refresh = function(self)
		if EP.db then
			self:RefreshSwatches()
			self.threatCheck:SetChecked(EP.db.showThreat)
			if self.manaCheck then
				self.manaCheck:SetChecked(EP.db.showMana)
			end
			self.aurasCheck:SetChecked(EP.db.showAuras)
			SyncAuraChildChecks()
			SyncHealthChoosers()
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
		panel.threatCheck:SetChecked(EP.db.showThreat)
		if panel.manaCheck then
			panel.manaCheck:SetChecked(EP.db.showMana)
		end
		panel.aurasCheck:SetChecked(EP.db.showAuras)
		SyncAuraChildChecks()
		SyncHealthChoosers()
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
