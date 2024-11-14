boomspeed = 4
bam = 1
function onEvent(n,v1,v2)

if n == "Cam Boom Speed" then

boomspeed = tonumber(v1)
bam = tonumber(v2)

end

end
function onBeatHit()

	if curBeat % boomspeed == 0 then
		triggerEvent("Add Camera Zoom",0.015*bam,0.03*bam)
	end

end