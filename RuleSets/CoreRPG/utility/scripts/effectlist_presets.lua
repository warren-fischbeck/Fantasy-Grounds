--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	local tEffects = VisionManager.getLightPresetEffects();
	if #tEffects > 0 then
		for _,rEffect in ipairs(tEffects) do
			local w = lights_list.createWindow();
			w.setEffect(rEffect);
		end
	else
		lights_label.setVisible(false);
		lights_list.setVisible(false);
	end

	local tConditions = ActionCore.getConditions();
	if #tConditions > 0 then
		for _,sCondition in ipairs(tConditions) do
			local w = conditions_list.createWindow();
			w.setEffect({ sName = StringManager.capitalizeAll(sCondition) });
		end
	else
		conditions_label.setVisible(false);
		conditions_list.setVisible(false);
	end
end
