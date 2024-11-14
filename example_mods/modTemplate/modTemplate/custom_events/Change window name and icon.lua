function onEvent(name, v1, v2)
	if name == 'Window Name' then
        name = v1
        icon = v2
        if name ~= nil then
            setPropertyFromClass("openfl.Lib", "application.window.title", name)
        end
        if icon ~= nil then
            runHaxeCode("Application.current.window.setIcon(Image.fromFile(Paths.modFolders('images/"..icon..".png')));")
        end
    end
end

function onCreate()
    addHaxeLibrary('Application', 'lime.app')
    addHaxeLibrary('Image', 'lime.graphics')
end