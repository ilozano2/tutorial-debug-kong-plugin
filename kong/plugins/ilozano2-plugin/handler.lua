local Ilozano2PluginHandler = {
    PRIORITY = 1000,
    VERSION = "0.0.1",
}

function Ilozano2PluginHandler:access(config)
    require("mobdebug").start()
    --[[
        ... your code ...
    --]]

end

return Ilozano2PluginHandler