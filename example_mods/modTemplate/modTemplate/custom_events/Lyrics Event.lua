function onCreatePost()
    makeLuaText("BFLyrics", "", 1500, -120, 480)
    addLuaText("BFLyrics")
    setTextSize("BFLyrics", 32)
    setTextAlignment("BFLyrics", "center")
    setTextColor("BFLyrics", "00FFFF")

    makeLuaText("DADLyrics", "", 1500, getProperty("BFLyrics.x"), getProperty("BFLyrics.y") + 30)
    addLuaText("DADLyrics")
    setTextSize("DADLyrics", 32)
    setTextAlignment("DADLyrics", "center")
    setTextColor("DADLyrics", "909090")
end

function onEvent(name, value1, value2)
    if name == "Lyrics Event" then
        if value1 == 'BF' then
            setProperty("BFLyrics.text", value2)
        end

        if value1 == 'Dad' then
            setProperty("DADLyrics.text", value2)
        end

        if value1 == 'bf' then
            setProperty("BFLyrics.text", value2)
        end

        if value1 == 'dad' then
            setProperty("DADLyrics.text", value2)
        end
    end
end