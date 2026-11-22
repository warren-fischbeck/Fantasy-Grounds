--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onValueChanged()
	ActorCommonManager.onSizeChanged(window.getDatabaseNode());
	WindowManager.callOuterWindowFunction(window, "onSummaryChanged");
end

function onWheel(n)
	if isReadOnly() or not Input.isControlPressed() then
		return false;
	end

	local s = getValue();
	local sNew = ActorCommonManager.incrementSizeField(s, n);
	if not sNew then
		return true;
	end

	if sNew ~= s then
		setValue(sNew);
		ActorCommonManager.onSizeChanged(window.getDatabaseNode());
	end
	return true;
end
