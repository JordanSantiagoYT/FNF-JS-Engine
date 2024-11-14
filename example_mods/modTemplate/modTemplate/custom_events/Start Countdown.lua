function onCreatePost()
    precacheImage("ready")
    precacheImage("set")
    precacheImage("go")

    makeLuaSprite("readyH", "ready", 757, 364)
    makeLuaSprite("setH", "set", 702, 322)
    makeLuaSprite("goH", "go", 558, 430)

    setObjectCamera("readyH", 'camHud')
    setObjectCamera("setH", 'camHud')
    setObjectCamera("goH", 'camHud')

    addLuaSprite("readyH", true)
    addLuaSprite("setH", true)
    addLuaSprite("goH", true)

    setProperty("readyH.alpha", 0)
    setProperty("setH.alpha", 0)
    setProperty("goH.alpha", 0)

    screenCenter("readyH")
    screenCenter("setH")
    screenCenter("goH")
end

duralpha321go = "0.25"
function onEvent(eventName, value1, value2)
    if eventName == "Start Countdown" then
        if value1 == "3" then
            playSound("intro3")
        end

        if value1 == "2" then
            playSound("intro2")
            setProperty("readyH.alpha", 1)
            doTweenAlpha("readyH A", "readyH", 0, duralpha321go, "linear")
        end

        if value1 == "1" then
            playSound("intro1")
            setProperty("setH.alpha", 1)
            doTweenAlpha("setH A", "setH", 0, duralpha321go, "linear")
    
            cancelTween("readyH A")
            setProperty("readyH.alpha", 0)
        end

        if value1 == "go" then
            playSound("introGo")
            setProperty("goH.alpha", 1)
            doTweenAlpha("goH A", "goH", 0, duralpha321go, "linear")
    
            cancelTween("setH A")
            setProperty("setH.alpha", 0)
        end
    end
end