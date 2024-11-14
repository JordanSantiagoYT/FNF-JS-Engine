local focus = nil

function onEvent(name, value1, value2)
	if name == 'FocusCamera' then
	local gfCharacter = getProperty('gf.curCharacter')
	if value1 == '1' then
	cameraSetTarget('dad');
	focus = "dad"
	elseif value1 == '0' then
	cameraSetTarget('boyfriend');
	focus = "boyfriend"
	elseif value1 == '2' then
    focus = "gf"
	triggerEvent('Camera Follow Pos',getMidpointX('gf')+getProperty('gf.cameraPosition[0]') - 60,getMidpointY('gf')+getProperty('gf.cameraPosition[1]') + 35);
	elseif value1 == '3' then
	focus = nil
end
end
end

function onUpdate()
local gfCharacter = getProperty('gf.curCharacter')
if focus == "dad" then
cameraSetTarget('dad');
elseif focus == "boyfriend" then
cameraSetTarget('boyfriend');
elseif focus == "gf" then
triggerEvent('Camera Follow Pos',getMidpointX('gf')+getProperty('gf.cameraPosition[0]') - 60,getMidpointY('gf')+getProperty('gf.cameraPosition[1]')+ 35);
end
end