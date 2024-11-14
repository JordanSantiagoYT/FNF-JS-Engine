local on = false
function onCreatePost()
    getPropertyFromClass("ClientPrefs", "shaders");
    precacheImage("light/left");
    precacheImage("light/down");
    precacheImage("light/up");
    precacheImage("light/right")

    makeLuaSprite("colorSing", "light/left", 0, 0)
    addLuaSprite("colorSing")
    screenCenter("colorSing")
    setObjectCamera("colorSing", "other")
    setProperty('colorSing.alpha', 0);
    --setBlendMode("colorSing", "add")
end

function onUpdate()
    if on then
        colorSingMode = true
    else
        colorSingMode = false
    end
end

local dirName = {"left", "down", "up", "right"}
function goodNoteHit(id, dir)
    if colorSingMode then
        loadGraphic("colorSing", "light/" .. dirName[dir + 1])
        setProperty("colorSing.alpha", 1)
        doTweenAlpha("colorSingfade", "colorSing", 0, 1 / 1)
    end
    if not colorSingMode then
        --doTweenAlpha("colorSingfade", "colorSing", 0, 1 / 1)
    end
end

function onChange()
	if on then 
        on = false
    else
        on = true
    end
end

function onEvent(n)
	if n == 'Hype Mode' then
        onChange()
    end
end