-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	RecordManager.setRecordAddCallback("", OverlayRecordManager.onRecordAdd);
	RecordManager.setRecordDeleteCallback("", OverlayRecordManager.onRecordDelete);
end

function onRecordAdd(node, sRecordType, bIsSubRecord)
	if bIsSubRecord then
		return;
	end

	local sRecordType = RecordDataManager.getRecordTypeDisplayTextSingle(sRecordType);
	local sRecordName = RecordDataManager.getRecordDisplayName(node);
	local tOverlayData = {
		sOption = "TOAST_INTERFACE",
		sToastType = "add",
		sTitle = Interface.getString("record_toast_title_add"),
		sText = string.format(Interface.getString("record_toast_text_add"), sRecordType, sRecordName),
	};
	OverlayManager.showToastMessage(tOverlayData);
end
function onRecordDelete(node, sRecordType, bIsSubRecord)
	if bIsSubRecord then
		return;
	end

	local sRecordType = RecordDataManager.getRecordTypeDisplayTextSingle(sRecordType);
	local sRecordName = RecordDataManager.getRecordDisplayName(node);
	local tOverlayData = {
		sOption = "TOAST_INTERFACE",
		sToastType = "delete",
		sTitle = Interface.getString("record_toast_title_delete"),
		sText = string.format(Interface.getString("record_toast_text_delete"), sRecordType, sRecordName),
	};
	OverlayManager.showToastMessage(tOverlayData);
end
