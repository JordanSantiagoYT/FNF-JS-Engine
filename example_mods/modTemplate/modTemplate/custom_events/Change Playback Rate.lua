function onEvent(eventName, value1, value2, strumTime)
    if eventName == "Change Playback Rate" then
        setProperty("playbackRate", value1)
    end
end
