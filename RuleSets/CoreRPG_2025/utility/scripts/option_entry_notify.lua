--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function setReadOnly(bReadOnly)
	super.setReadOnly(bReadOnly);

	checkbox.setReadOnly(bReadOnly);
	duration.setReadOnly(bReadOnly);
end

function getDisplayValue()
	return self.getOptionValue();
end
function getOptionValue()
	local nDuration = math.max(duration.getValue(), 0);
	if (checkbox.getValue() == 0) then
		if nDuration > 0 then
			return tostring(-nDuration);
		end
		return tostring(-OverlayManager.getOptionDurationDefault(self.getKey()));
	end
	return tostring(nDuration);
end
function onSetOptionValue(s)
	local n = tonumber(s) or 0;
	if n < 0 then
		checkbox.setValue(0);
		duration.setValue(-n);
		duration.setVisible(false);
	else
		checkbox.setValue(1);
		duration.setValue(n);
		duration.setVisible(true);
	end
	if duration.isVisible() then
		checkbox.setAnchor("right", nil, "right", "absolute", -95);
	else
		checkbox.setAnchor("right", nil, "right", "absolute", -58);
	end
end
