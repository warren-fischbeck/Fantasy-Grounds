--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

DEFAULT_TOAST_COMBAT_NOTIFY_DURATION = 5;
DEFAULT_TOAST_INTERFACE_NOTIFY_DURATION = 3;
DEFAULT_TOAST_TURN_NOTIFY_DURATION = 3;
DEFAULT_SPEECH_NOTIFY_DURATION = 5;
DEFAULT_TOKEN_NOTIFY_DURATION = 5;

function getOptionDuration(sOption)
	if (sOption or "") == "" then
		sOption = "TOAST_COMBAT";
	end
	return tonumber(OptionsManager.getOption(sOption)) or OverlayManager.getOptionDurationDefault(sOption);
end
function getOptionDurationDefault(sOption)
	if (sOption or "") == "TOKEN_SPEECH" then
		return OverlayManager.DEFAULT_SPEECH_NOTIFY_DURATION;
	elseif (sOption or "") == "TOKEN_COMBAT" then
		return OverlayManager.DEFAULT_TOKEN_NOTIFY_DURATION;
	end
	return OverlayManager.DEFAULT_TOAST_COMBAT_NOTIFY_DURATION;
end

function showToastMessage(tData)
	if not tData then
		return;
	end

	local nDuration = OverlayManager.getOptionDuration(tData.sOption);
	if nDuration < 0 then
		return;
	end

	local sToastType = tData.sToastType or "";
	if not StringManager.contains({ "add", "delete", "success", "failure", }, sToastType) then
		sToastType = "info";
	end
	local sAsset = "toast-" .. sToastType;

	local sIcon = tData.sIcon or sAsset;
	local sIconColor = tData.sIconColor or "FFFFFF";

	local sTitlePart = string.format("<font name=\"toast-title\" size=18>%s\n</font>", tData.sTitle or "");
	local sTextPart = string.format("<font name=\"toast-text\" size=14>%s\n</font>", tData.sText or "");
	local sMessage  = string.format("%s%s", sTitlePart, sTextPart);

	local sOptLocation = OptionsManager.getOption("TOAST_LOCATION");
	local sAnchorTo = "top";
	local nAnchorOffsetX = 0;
	if sOptLocation == "topleft" then
		sAnchorTo = "topleft";
		nAnchorOffsetX = 400; -- Half message (200) width plus offset
	elseif sOptLocation == "topright" then
		sAnchorTo = "topright";
		nAnchorOffsetX = -400; -- Half message (200) width plus offset
	end

	local tOverlayData = {
		name = "toast",
		relativetype = "toast",
		anchor = "bottom",
		anchorto = sAnchorTo,
		offset = { nAnchorOffsetX, 18, },
		size = { 400, 0, },
		frame = { name = sAsset, offset = "30,12,24,18", },
		image = { icon = sIcon, color = sIconColor, anchor = "left", size = { 24, 24, }, },
		text = { text = sMessage, anchor = "left", offset = { 32, 0, }, },
		sequence = {
			{
				anchor = "top",
				offset = { nAnchorOffsetX, 22, },
				relativeto = "bottom",
				relativeoffset = { 0, 28, },
				duration = 0.25,
				curve = "fast",
			},
			{
				duration = nDuration,
			},
			{
				anchor = "bottom",
				offset = { nAnchorOffsetX, 18, },
				duration = 0.25,
				curve = "ease",
			},
		},
	};
	Interface.addOverlayEffect(tOverlayData);
end
function showFullScreenMessage(tData)
	if not tData then
		return;
	end

	local nDuration = OverlayManager.getOptionDuration(tData.sOption);
	if nDuration < 0 then
		return;
	end

	local sColor = tData.sColor or "FFFFFF";
	local sOutlineColor = tData.sOutlineColor or "2F85EC";

	local sMessage = string.format(
			"<font name=\"fullscreen-text\" size=96 color=#%s outline=0.5 outlineColor=#%s shadow=0.125 shadowColor=#000000e1 shadowBlur=1>%s\n</font>",
			sColor, sOutlineColor, tData.sText or ""
			);
	local tOverlayData = {
		name = "full-screen-text",
		text = { text = sMessage, },
		scale = { 1, 0, },
		sequence = {
			{
				scale = { 1, 1, },
				duration = 0.25,
				curve = "fast",
			},
			{
				duration = nDuration,
			},
			{
				scale = { 1, 0, },
				duration = 0.25,
				curve = "fast",
			},
		}
	};
	Interface.addOverlayEffect(tOverlayData);
end

function showActorSpeech(rActor, tData)
	local sOpt = OptionsManager.getOption("CHATMAP");
	if sOpt == "image" then
		OverlayManager.showImageSpeech(rActor, tData);
	elseif sOpt == "token" then
		OverlayManager.showTokenSpeech(rActor, tData)
	end
end
function showImageSpeech(rActor, tData)
	if not tData or ((tData.sText or "") == "") then
		return;
	end
	local tokenActor = ImageManager.getActiveImageToken(rActor);
	if not tokenActor then
		return;
	end

	local nDuration = OverlayManager.getOptionDuration("TOKEN_SPEECH");
	if nDuration < 0 then
		return;
	end

	local sIcon = "";
	local sAsset = tokenActor.getPrototype();
	if (sAsset or "") == "" then
		sIcon = "charlist_base";
	end
	local sMessage  = string.format("<font name=\"image-speech\" size=16>%s</font>", tData.sText or "");

	local tOverlayData = {
		name = "image-speech-actor",
		displaytype = "overlay",
		relativetype = "image-speech-actor",
		anchor = "topleft",
		anchorto = "topleft",
		offset = { 10, 10, },
		relativeto = "bottomleft",
		relativeoffset = { 0, 20, },
		frame = { name = "image-speech", offset = "0,10,10,10", },
		image = { asset = sAsset, icon = sIcon, anchor = "topleft", size = { 50, 50, }, },
		text = { text = sMessage, anchor = "left", offset = { 90, 0, }, },
		size = { 300, 0, },
		minsize = { 200, 0, },
		sequence = {
			{
				duration = nDuration,
			},
			{
				anchor = "bottomleft",
				offset = { 10, 10, },
				duration = 0.25,
				curve = "ease",
			},
		},
	};
	Image.addOverlayEffect(tokenActor.getContainerNode(), tOverlayData);
end
function showTokenSpeech(rActor, tData)
	if not tData then
		return;
	end
	local tokenActor = ImageManager.getActiveImageToken(rActor);
	if not tokenActor then
		return;
	end
	if not Session.IsHost and not Token.isVisible(tokenActor) then
		return;
	end

	local nDuration = OverlayManager.getOptionDuration("TOKEN_SPEECH");
	if nDuration < 0 then
		return;
	end

	local sMessage  = string.format("<font name=\"token-speech\" size=16>%s</font>", tData.sText or "");

	local tOverlayData = {
		name = "token-speech",
		size = { 200, 0, },
		minsize = { 100, 0, },
		anchor = "bottomleft",
		anchorto = "topleft",
		offset = { -5, -32, },
		frame = { name = "token-speech", offset = "10,10,10,30", },
		text = { text = sMessage,  },
		color = "00FFFFFF",
		sequence = {
			{
				color = "FFFFFFFF",
				duration = 0.2,
			},
			{
				duration = nDuration,
			},
			{
				color = "00FFFFFF",
				duration = 0.2,
			},
		}
	};
	Token.addOverlayEffect(tokenActor, tOverlayData);
end

function showTokenIconQuick(rActor, tData)
	local tokenActor = ImageManager.getActiveImageToken(rActor);
	if not tokenActor then
		return;
	end

	local tIconOverlayData = OverlayManager.helperGetTokenIconQuickData(tData);
	if not tIconOverlayData then
		return;
	end

	local tAccentOverlayData = OverlayManager.helperGetTokenIconQuickAccentData(tData);

	local tAllOverlayData = { name="token-icon", effects = {}, };
	if tAccentOverlayData then
		table.insert(tAllOverlayData.effects, tAccentOverlayData);
	end
	table.insert(tAllOverlayData.effects, tIconOverlayData);

	Token.addOverlayEffect(tokenActor, tAllOverlayData);
end
function helperGetTokenIconQuickData(tData)
	if not tData or ((tData.sIcon or "") == "") then
		return nil;
	end

	local nDuration = OverlayManager.getOptionDuration("TOKEN_COMBAT");
	if nDuration < 0 then
		return nil;
	end

	local sStartColor = tData.sColor or "FFFFFF";
	local sEndColor = string.format("00%s", sStartColor);
	local nSize = tonumber(tData.nSize) or 40;

	local tIconOverlayData = {
		name = "token-icon-quick",
		image = { icon = tData.sIcon, size = { nSize, nSize, }, },
		scale = { 0, 0, },
		color = sStartColor,
		sequence = {
			{
				scale = { 1, 1, },
				duration = 0.5,
				ease = "fast",
			},
			{
				duration = nDuration,
			},
		},
	};
	if (tData.sText or "") ~= "" then
		local sText = string.format("<font name=\"black-title\" size=10 color=FFFFFF outline=0.5 outlineColor=000000>%s</font>", tData.sText);
		tIconOverlayData.text = { text = sText, offset = { 0, -25, }, };
	end
	if tData.bTraverseResult then
		table.insert(tIconOverlayData.sequence, 1, { duration = 0.375, });
	end
	local tFadeStep = { color = sEndColor, scale = { 0, 0, }, duration = 0.5, curve = "ease", };
	if (tData.sFadeDirection or "") ~= "" then
		tFadeStep.anchorto = tData.sFadeDirection;
	end
	table.insert(tIconOverlayData.sequence, tFadeStep);

	return tIconOverlayData;
end
function helperGetTokenIconQuickAccentData(tData)
	if not tData or not tData.bAccent then
		return nil;
	end

	local sAccentColor = tData.sAccentColor or "FFFFFF";

	local tAccentOverlayData = {
		name = "token-effect-add-accent",
		image = { icon = "effect-add-accent", color = sAccentColor },
		size = { 75, 75 },
		scale = { 0, 0 },
		sequence = {
			{
				scale = { 1, 1 },
				angle = 15,
				duration = 0.25,
			},
			{
				angle = 75,
				duration = 1,
			},
			{
				scale = { 0, 0 },
				duration = 0.5,
				angle = 105,
			},
		}
	};
	if tData.bTraverseResult then
		table.insert(tAccentOverlayData.sequence, 1, { duration = 0.375, });
	end

	return tAccentOverlayData;
end
function showTokenIconTraverse(rSource, rTarget, tData)
	if not tData or ((tData.sIcon or "") == "") then
		return;
	end
	local tokenSource = ImageManager.getActiveImageToken(rSource);
	local tokenTarget = ImageManager.getActiveImageToken(rTarget);
	if not tokenSource or not tokenTarget then
		return;
	end
	if tokenSource.getContainerNode() ~= tokenTarget.getContainerNode() then
		return;
	end

	local nDuration = OverlayManager.getOptionDuration("TOKEN_COMBAT");
	if nDuration < 0 then
		return;
	end

	local xs, ys = tokenSource.getPosition();
	local xt, yt = tokenTarget.getPosition();
	local nSize = tonumber(tData.nSize) or 50;
	local tOverlayData = {
		name = "token-icon-traverse",
		image = { icon = tData.sIcon, size = { nSize, nSize, }, },
		offset = { xs, ys, },
		color = "FFFFFF",
		sequence = {
			{
				offset = { xt, yt, },
				duration = 0.5,
				color = "00FFFFFF",
			},
		},
	};
	Image.addOverlayEffect(tokenTarget.getContainerNode(), tOverlayData);
end
function showTokenIconTraverseResult(rActor, tData)
	if not tData then
		return;
	end
	tData.bTraverseResult = true;
	OverlayManager.showTokenIconQuick(rActor, tData);
end
function showTokenIconDamage(rActor, tData)
	if not tData or ((tData.sIcon or "") == "") then
		return;
	end
	local tokenActor = ImageManager.getActiveImageToken(rActor);
	if not tokenActor then
		return;
	end

	local nDuration = OverlayManager.getOptionDuration("TOKEN_COMBAT");
	if nDuration < 0 then
		return;
	end

	local sText = string.format("<font name=\"token-damage\" size=35 color=%s outline=0.25 outlineColor=#000000>%d</font>", tData.sColor, tData.nTotal);
	local tOverlayData = {
		name = "token-damage",
		anchor = "bottom",
		anchorto = "top",
		scale = { 0, 0, },
		size = { 0, 35, },
		image = { icon = tData.sIcon, color = tData.sColor, anchor = "left", size = { 30, 30, }, },
		text = { text = sText, anchor = "left", offset = { 40, 0, }, },
		sequence = {
			{
				duration = (tData.nSlot or 0) * 0.25,
			},
			{
				scale = { 1, 1, },
				offset = { 0, -20 - ((tData.nSlot or 0) * 20), },
				shake = { 1, 0, 20, 0, },
				duration = 1,
				curve = "fast",
			},
			{
				offset = { 0, -35 - ((tData.nSlot or 0) * 20), },
				shake = { 5, 0, 20, 0, },
				color = "00FFFFFF",
				duration = 0.5,
				curve = "ease",
			},
		},
	}
	Token.addOverlayEffect(tokenActor, tOverlayData);
end
function showTokenIconEffectAdd(rActor, tData)
	if not tData then
		return;
	end
	local tokenActor = ImageManager.getActiveImageToken(rActor);
	if not tokenActor then
		return;
	end

	tData.bAccent = true;
	if (tData.sType or "") == "bonus" then
		tData.sAccentColor = "228830";
	elseif (tData.sType or "") == "penalty" then
		tData.sAccentColor = "6D1B1B";
	end

	tData.sText = tData.sText or tData.sName;
	tData.sFadeDirection = "topleft";
	OverlayManager.showTokenIconQuick(rActor, tData);
end
