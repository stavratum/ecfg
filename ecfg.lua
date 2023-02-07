local base = { nullptr = {} }
local mt = { __call = function(self) local result = {} for i,v in pairs(self) do result[i] = type(v) == "table" and getmetatable(self).__call(v) or v end return setmetatable(result, nil) end }

setmetatable(base, mt)

base.unique_kv_types = { ["boolean"] = true, ["number"] = true, ["table"] = true }
base.escape_map = { encode = "\\'\"bfnrt", decode = "\\'\"\b\f\n\r\t" }
base.encode_map = {
    ["string"] = function(v, self)
        local encoded = string.gsub(v, ".", function(character)
            local index = string.find(self.escape_map.decode, character)
            return index ~= nil and "\\" .. string.sub(self.escape_map.encode, index, index) or character
        end)
            
        return '"' .. encoded .. '"'
    end,
    ["number"] = tostring,
    ["boolean"] = tostring,
    ["nil"] = function() return "..." end,
    ["table"] = function(v, self)
        local encoded = ""
            
        for i = 1, #v do
            encoded = encoded .. self.encode_map[type(v[i])](v[i], self) .. ", "
        end

        return "[" .. string.sub(encoded, 1, #encoded - 2) .. "]"
    end
}

--
--
--

local ecfg = base()

local decode_value; decode_value = function(v, opt)
    assert(type(v) == "string", "string expected")
    
    local map = { ["true"] = true, ["false"] = false, ["..."] = opt.nullptr }

    if map[v] ~= nil then
        return map[v]
    elseif tonumber(v) then
        return tonumber(v)
    end
    
    local first, last = v:sub(1, 1), v:sub(-1)
    local map = {{"'","'"}, {'"','"'}, {"[","]"}}
    local type = nil

    for i, wraps in ipairs(map) do
        if wraps[1] == first and wraps[2] == last then 
            type = i
            break
        end
    end

    if type == 3 then
        local content = v:match("%[(.*)%]")
        local result = {}
        
        for item in content:gmatch("([^,]+),? *") do
            result[#result + 1] = decode_value(item)
        end

        return result
    elseif ({true, true})[type] then
        local content = v:sub(2, #v - 1)
        local character = ({"'", '"'})[type]

        if content == character or content:match("[^\\]" .. character) then
            error("couldn't decode. Unescaped character (" .. character .. ") in string: " .. content)
        end
        
        content = content:gsub("\\(.)", function(character)
            local index = string.find(opt.escape_map.encode, character)
            assert(index ~= nil, "invalid escape sequence")

            local esc = string.sub(opt.escape_map.decode, index, index)
            return esc
        end)
        
        return content
    end

    error("couldn't decode: " .. v)
end

function ecfg:decode(v)
    local function split(input, separator)
        local matches = {}
        for match in string.gmatch(input, "([^"..separator.."]+)") do
            matches[#matches + 1] = match
        end
        
        return matches
    end

    local lines = split(v, "\n")
    local result = {}

    for _,line in ipairs(lines) do
        line = line:gsub("^%s*", "")

        local str = false
            
        for i = 1, #line do
            local character = string.sub(line, i,i)
            if character == "'" or character == '"' then
                str = not str
            elseif character == ";" and string.sub(line, i+1,i+1) == ";" and not str then
                line = string.sub(line, 1, i - 1)
                break
            end
        end
            
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
                    
                    value = string.sub(value, 1, #value - 1)
                    break
                end
            end

            if string.sub(kv, 1, 1) == "[" and string.sub(kv, #kv, #kv) == "]" then
                local content = string.sub(kv, 2, #kv - 1)
                kv = decode_value(content, self)
            end
            
            result[kv] = decode_value(value, self)
        end
    end

    return result
end

function ecfg:encode(v)
    local map = self.encode_map
    local typev = type(v)
    
    if typev == "table" then
        local res = ""

        for i,v in pairs(v) do
            local kv = tostring(i)
            res = res .. string.format((self.unique_kv_types[type(i)] and "[%s]" or "%s") .. " %s\n", kv, map[type(v)](v, self))
        end

        return res:sub(1, #res - 1)
    end

    return map[typev](v, map)
end

return ecfg, base
