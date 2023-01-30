local function indexOf(array, value)
    for i = 1, #array do
        if value == array[i] then
            return i
        end
    end

    return -1
end

--

local esc_cmi = {"\\", '\'', "\"", "\b", "\f", "\n", "\r", "\t"}
local esc_cmv = {"\\", "'", "\"", "b", "f", "n", "r", "t"}

local literalsi = {"...", "false", "true"}
local literalsv = {nil, false, true}

local ecfg = {}
local type_map; type_map = {
    encode = {
        ["boolean"] = tostring,
        ["number"] = tostring,
        ["nil"] = function() return "..." end,
        ["string"] = function(v)
            local content = v:gsub('[%z\1-\31\\"\']', function(character)
                return "\\"..esc_cmv[indexOf(esc_cmi, character)]
            end)
            
            return '"'..content..'"'
        end,
        ["table"] = function(array)
            local res = ""
            for i = 1, #array do
                local v = array[i]
                res = res..type_map.encode[ type(v) ](v)
                if i ~= #array then
                    res = res..", "
                end
            end
            return "["..res.."]"
        end
    },
    decode = {
        ["number"] = tonumber,
        ["literal"] = function(v)
            return literalsv[ indexOf(literalsi, v) ]
        end,
        ["unidentified"] = function(v)
            return nil
        end,
        ["string"] = function(v, quote)
            local content = v:match(quote.."(.*)"..quote)
            
            return content:gsub("\\\\(.)", function(character)
                return esc_cmi[ indexOf(esc_cmv, character) ]
            end)
        end,
        ["table"] = function(v)
            local content = v:match("%[([^%]]*)%]")
            local res = {}

            for value in content:gmatch("([^,]*),? *") do
                local type, complex = ecfg.typeof(v)
                res[#res + 1] = type_map.decode[type](v, complex)
            end

            return res
        end
    }
}

function ecfg.typeof(v)
    if indexOf(literalsi, v) ~= -1 then
        return "literal"
    elseif tonumber(v) then
        return "number"
    elseif v:match("%[.*%]") then
        return "table"
    else
        local quote = v:sub(1, 1)
        
        if indexOf({'"', "'"}, quote) == -1 or quote ~= v:sub(-1) then
            return "unidentified"
        end
        
        for i = 2, #v - 1 do
            local character = v:sub(i, i)
            if indexOf({"\\", quote}, character) ~= -1 and v:sub(i-1, i-1) ~= "\\" then
                return "unidentified"
            end
        end

        return "string", quote
    end
end

function ecfg.encode(data)
    local res = ""
    for kv,v in pairs(data) do
        local encoded = type_map.encode[type(v)](v)
        res = res..("%s %s\n"):format(kv, encoded)
    end
    return res:sub(1, #res-1)
end

function ecfg.decode(data)
    local function split(input, separator)
        local matches = {}
        for match in input:gmatch("([^"..separator.."]+)") do
            matches[#matches + 1] = match
        end
        
        return matches
    end

    local lines = split(data, "\n")
    local res = {}
        
    for _,line in ipairs(lines) do
        for awesome in line:gmatch"\"|'?( *;;.*)$" do
            line = line:gsub(awesome, "")
        end
        line = line:gsub("^[ \t]*", "")
        
        if line ~= "" then
            local content = split(line, " ")
            local kv, value = "", ""

            for i,v in ipairs(content) do
                if i ~= #content and not v:match("[\"']") then
                    kv = kv..v
                else
                    local left = #content - i
                    for i = i, #content do
                        value = value .. content[i] .. " "
                    end
                    value = value:sub(1, #value - 1)
                    break
                end
            end

            local type, complex = ecfg.typeof(value)
            res[kv] = type_map.decode[type](value, complex)
        end
    end

    return res
end

return ecfg, type_map
