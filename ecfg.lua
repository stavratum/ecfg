--

local function split(input, sep)
   local matches = {}
        
    if not sep then
        return nil
    end
        
    for match in input:gmatch("([^"..sep.."]+)") do
        table.insert(matches, match)
    end
        
    return matches
end

local function indexOf(array, value)
    for i,v in ipairs(array) do
        if v == value then
            return i
        end
    end

    return -1
end

--

local ecfg = {}
local converter = {}
local types = { ecfg = {"undefined", "false", "true"}, lua = {nil, false, true} }

function converter.tolua(v)
    local index = indexOf(types.ecfg, v)
    local success = index ~= -1

    return success, success and types.lua[index] or nil
end

function converter.toecfg(v)
    local index = indexOf(types.lua, v)
    local success = index ~= -1

    return success, success and types.ecfg[index] or nil
end

function ecfg:encode()

end

function ecfg:decode(data)
    local lines = split(data, "\n")
    local result = { }
     
    for _,line in ipairs(lines) do
        local i,v = table.unpack(split(line, " "))
        local success, converted = converter.tolua(v)
        
        if success then result[i] = converted else
            result[i] = v
        end
    end
    
    return result
end

return ecfg, converter
