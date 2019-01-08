	
	--[[

		SlyFox
			A combopoint and energy tracker for WoW TBC 2.4.3
			
			by null
			https://github.com/nullfoxh/SlyFox

	]]--


	-- config

	local frameWidth = 130
	local comboHeight = 7
	local energyHeight = 7
	local framePos = { 0, -224 }

	local showTick = true

	local smoothBars = true
	local smoothTime = 0.1

	local showText = true
	local fontSize = 20

	local fadeFrame = true
	local fadeInTime = 0.07
	local fadeOutTime = 0.15


	energycolor = { 255/255, 225/255, 26/255}
	cpcolors = {
			[1] = { 208/255, 120/255, 72/255 },
			[2] = { 240/255, 190/255, 89/255 },
			[3] = { 216/255, 231/255, 92/255 },
			[4] = { 139/255, 243/255, 83/255 },
			[5] = { 60/255, 255/255, 73/255 },
	}

	local font = "Interface\\AddOns\\SlyFox\\homespun.ttf"
	local texture = "Interface\\AddOns\\SlyFox\\statusbar.tga"

	---------------------------------------------------------------------------------------------

	local lastTick = 0
	local nextTick = 0
	local curEnergy, maxEnergy, cpoints, inCombat, smoothing
	local stealthed, hasTarget, powerType, class, firstEvent

	local GetTime, MAX_COMBO_POINTS, min
		= GetTime, MAX_COMBO_POINTS, math.min
	
	local UnitMana, UnitManaMax, UnitPowerType, IsStealthed, GetComboPoints, UnitCanAttack
		= UnitMana, UnitManaMax, UnitPowerType, IsStealthed, GetComboPoints, UnitCanAttack

	local print = function(s) DEFAULT_CHAT_FRAME:AddMessage("|cffa0f6aaSlyFox|r: "..s) end

	local SlyFox = CreateFrame("Frame", nil, UIParent)

	---------------------------------------------------------------------------------------------

	local function CreateTex(frame, a, b, x, y, layer, tex)
		local bg = frame:CreateTexture(nil, layer or "BACKGROUND")
		bg:SetPoint("TOPLEFT", frame, a or -1, b or 1)
		bg:SetPoint("BOTTOMRIGHT", frame, x or 1, y or -1)
		bg:SetTexture(tex or "Interface\\ChatFrame\\ChatFrameBackground")
		bg:SetVertexColor(0, 0, 0)
		return bg
	end

	local function CreateFrames()	

		-- energy
		local e = CreateFrame("Frame", nil, SlyFox)
		e:SetWidth(frameWidth)
		e:SetHeight(energyHeight)
		e:SetPoint("CENTER", UIParent, "CENTER", framePos[1], framePos[2])
		SlyFox.energy = e

		-- bar
		e.bar = CreateFrame("StatusBar", nil, e)
		e.bar:SetStatusBarTexture(texture)
		e.bar:SetPoint("TOPLEFT", 1, -1)
		e.bar:SetPoint("BOTTOMRIGHT", -1, 1)
		e.bar:SetMinMaxValues(0, maxEnergy)
		e.bar:SetValue(curEnergy)

		-- bg
		local r, g, b = unpack(energycolor)
		e.bar:SetStatusBarColor(r, g ,b)
		e.bg = CreateTex(e, 0, 0, 0, 0, "BACKGROUND")
		e.bd = CreateTex(e, 1, -1, -1, 1, "BORDER", texture)
		e.bd:SetVertexColor(r, g, b, 0.25)

		-- text
		if showText then
			e.text = e:CreateFontString(nil, "OVERLAY")
			e.text:SetFont(font, fontSize, "OUTLINE")
			e.text:SetShadowColor(0, 0, 0)
			e.text:SetShadowOffset(1, -1)
			e.text:SetPoint("TOP", e, "BOTTOM", 0, 0)
			e.text:SetJustifyH("CENTER")
			e.text:SetTextColor(r, g, b)
			e.text:SetText(curEnergy)
		end

		-- spark
		if showTick then
			e.spark = e.bar:CreateTexture(nil, "OVERLAY")
			e.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
			e.spark:SetBlendMode("ADD")
			e.spark:SetWidth(energyHeight+4)
			e.spark:SetHeight(energyHeight+4)
			e.spark:Show()
		end

		-- combopoints
		SlyFox.cp = {}

		for i = 1, MAX_COMBO_POINTS do
			local c = CreateFrame("Frame", nil, SlyFox)
			c:SetWidth((frameWidth+MAX_COMBO_POINTS-1)/MAX_COMBO_POINTS)
			c:SetHeight(comboHeight)

			c.bg = CreateTex(c, 0, 0, 0, 0, "BACKGROUND")
			c.bd = CreateTex(c, 1, -1, -1, 1, "BORDER", texture)
			c.fg = CreateTex(c, 1, -1, -1, 1, "ARTWORK", texture)
			c.fg:Hide()
	 
			local r, g, b = unpack(cpcolors[i])
			c.fg:SetVertexColor(r, g, b)
			c.bd:SetVertexColor(r, g, b, 0.25)

			SlyFox.cp[i] = c

			if i > 1 then
				c:SetPoint("TOPLEFT", SlyFox.cp[i-1], "TOPRIGHT", -1, 0)
			else
				c:SetPoint("BOTTOMLEFT", SlyFox.energy, "TOPLEFT", 0, -1)
			end
		end
	end

	---------------------------------------------------------------------------------------------

	local function InitFrames()
		powerType = UnitPowerType("player")
		curEnergy, maxEnergy = UnitMana("player"), UnitManaMax("player")
		SlyFox.energy.bar:SetMinMaxValues(0, maxEnergy)
		SlyFox.energy.bar:SetValue(curEnergy)
		if showText then
			SlyFox.energy.text:SetText(curEnergy)
		end
	end

	local function StartFrameFade(frame, show)
		if show and frame.hidden then
			UIFrameFadeIn(frame, fadeInTime, 0, 1)
			frame.hidden = false
		elseif not show and not frame.hidden then
			UIFrameFadeOut(frame, fadeOutTime, 1, 0)
			frame.hidden = true
		end
	end

	local function UpdateEnergy()
		local newEnergy = UnitMana("player")

		if smoothBars then
			if smoothing then
				SlyFox.energy.bar:SetValue(curEnergy)
			else
				smoothing = true
			end
			SlyFox.energy.bar.start = curEnergy
			SlyFox.energy.bar.target = newEnergy
			SlyFox.energy.bar.startTime = GetTime()
		else
			SlyFox.energy.bar:SetValue(newEnergy)
		end

		if showText then
			SlyFox.energy.text:SetText(newEnergy)
		end

		if showTick then
			if newEnergy == curEnergy + 20 then
				local time = GetTime()
				lastTick = time
				nextTick = time + 2
			end
		end
		curEnergy = newEnergy
	end

	local function UpdateCombo()
		hasTarget = UnitCanAttack("player", "target")
		points = GetComboPoints("player", "target")
		for i = 1, MAX_COMBO_POINTS do
			if i > points then
				SlyFox.cp[i].fg:Hide()
			else
				SlyFox.cp[i].fg:Show()
			end
		end
	end

	---------------------------------------------------------------------------------------------

	local function OnEvent(self, event, unit)

		if not firstEvent then
			InitFrames()
			firstEvent = true
		end
			
		if event == "PLAYER_COMBO_POINTS" or event == "PLAYER_TARGET_CHANGED" then
			UpdateCombo()

		elseif event == "UNIT_ENERGY" then
			UpdateEnergy()

		elseif event == "UNIT_MAXENERGY" then
			InitFrames()

		elseif event == "PLAYER_REGEN_DISABLED" then
			inCombat = true

		elseif event == "PLAYER_REGEN_ENABLED" then
			inCombat = false

		elseif event == "UPDATE_STEALTH" then
			stealthed = IsStealthed()

		elseif event == "UNIT_DISPLAYPOWER" and unit == "player" then
			powerType = UnitPowerType("player")
			if powerType == 3 then
				InitFrames()
			end

		elseif event == "PLAYER_LOGIN" then
			InitFrames()
		end

		-- show/hide
		if powerType == 3 and (not fadeFrame or (points and points > 0) or stealthed or inCombat or hasTarget or curEnergy ~= maxEnergy) then
			StartFrameFade(SlyFox, true)
		else
			StartFrameFade(SlyFox, false)
		end
	end

	local function OnUpdate(self, elapsed)

		if showTick then
			local time = GetTime()

			if nextTick == 0 then
				lastTick = time
				nextTick = time + 2
			elseif time > nextTick then
				lastTick = nextTick
				nextTick = nextTick + 2
			end

			if not SlyFox.hidden then
				local pct = (time - lastTick) * 0.5
				SlyFox.energy.spark:SetPoint("CENTER", SlyFox.energy.bar, "LEFT", pct * frameWidth, 0)
			end
		end

		if smoothing then
			local cur = SlyFox.energy.bar:GetValue()
			local start = SlyFox.energy.bar.start
			local target = SlyFox.energy.bar.target

			local pct = min(1, (GetTime() - SlyFox.energy.bar.startTime) / smoothTime)
			local new = start + (target - start) * pct

			if new ~= cur then
				SlyFox.energy.bar:SetValue(new)
			end

			if pct == 1 then
				smoothing = false
			end
		end
	end

	---------------------------------------------------------------------------------------------

	class = select(2, UnitClass("player"))

	if class == "ROGUE" or class == "DRUID" then

		if fadeFrame or class == "DRUID" then
			SlyFox:SetAlpha(0)
			SlyFox.hidden = true
		end

		powerType = UnitPowerType("player")
		curEnergy, maxEnergy = UnitMana("player"), UnitManaMax("player") or 100
		CreateFrames()

		SlyFox:SetScript("OnEvent", OnEvent)
		SlyFox:RegisterEvent("UNIT_ENERGY")
		SlyFox:RegisterEvent("UNIT_MAXENERGY")
		SlyFox:RegisterEvent("PLAYER_COMBO_POINTS")
		SlyFox:RegisterEvent("PLAYER_TARGET_CHANGED")
		SlyFox:RegisterEvent("PLAYER_LOGIN")

		if fadeFrame then
			SlyFox:RegisterEvent("UPDATE_STEALTH")
			SlyFox:RegisterEvent("PLAYER_REGEN_ENABLED")
			SlyFox:RegisterEvent("PLAYER_REGEN_DISABLED")
		end

		if class == "DRUID" then
			SlyFox:RegisterEvent("UNIT_DISPLAYPOWER")
		end

		if showTick or smoothBars then
			SlyFox:SetScript("OnUpdate", OnUpdate)
		end
	end

	---------------------------------------------------------------------------------------------
