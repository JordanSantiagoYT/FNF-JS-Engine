function onEvent(name, value1, value2)
    if name == "Jumpscare Event" then
        
		local image = value1
        local sound = value2

        makeLuaSprite('jumpscareImage', image, 0, 0)
        setObjectCamera('jumpscareImage', 'other')
        addLuaSprite('jumpscareImage', true)
        playSound(sound, 1, "jumpscare")

        runTimer('jumpscareremove', 0.5)
    end
end

function onTimerCompleted(tag, loops, loopsLeft)
    if tag == 'jumpscareremove' then
        removeLuaSprite("jumpscareImage")
        stopSound("jumpscare")
    end
end