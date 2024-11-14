-- Event notes hooks
function onEvent(name, value1, value2)
	if name == 'Zoom Camera' then
		setProperty('defaultCamZoom', value1);
	end
end