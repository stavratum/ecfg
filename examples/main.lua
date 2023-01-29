local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    
    local content = file:read("*all")
    file:close()
    
    return content
end

math.randomseed(os.clock())
local ecfg = require('ecfg')

local config = ecfg.decode(read_file("config.ecfg")) -- read file content and decode
local success, result = pcall(function() (nil)() end)

if not success then
    local messages = config["message:error"]
    local index = math.random(#messages)
  
    print(string.format(messages[index], result))
end

print(config["assets:cat"])
print(config["assets:bunny"])
