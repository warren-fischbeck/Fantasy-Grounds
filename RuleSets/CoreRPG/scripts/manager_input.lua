--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--luacheck: globals Input.isAltPressed

-- NOTE: In general; please do not use Alt key as a modifier key for actions.
--		While it is tempting to have another modifier key for shortcuts and the API is there,
--		it can be problematic for people using for voice chat push-to-talk as well as some European users (Alt+Gr key)

local _fnOrigInputAltPressed;

function onInit()
	OptionsManager.registerOptionData({	sKey = "KALT", bLocal = true, tCustom = { default = "on", }, });

	_fnOrigInputAltPressed = Input.isAltPressed;
	Input.isAltPressed = InputManager.isAltPressed;
end

function isAltPressed()
	return OptionsManager.isOption("KALT", "on") and _fnOrigInputAltPressed();
end
function isAltPressedRaw()
	return _fnOrigInputAltPressed();
end
