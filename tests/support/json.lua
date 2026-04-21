local Json = {}

local function decodeError(message, position)
  error(string.format("json decode error at byte %d: %s", tonumber(position) or 0, tostring(message)), 0)
end

local function decode(text)
  local input = tostring(text or "")
  local length = #input
  local position = 1

  local parseValue

  local function skipWhitespace()
    while position <= length do
      local byte = input:byte(position)
      if byte ~= 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then
        break
      end
      position = position + 1
    end
  end

  local function parseString()
    if input:sub(position, position) ~= '"' then
      decodeError('expected string opening quote', position)
    end
    position = position + 1

    local chunks = {}
    while position <= length do
      local char = input:sub(position, position)
      if char == '"' then
        position = position + 1
        return table.concat(chunks)
      end
      if char == "\\" then
        local escaped = input:sub(position + 1, position + 1)
        if escaped == "" then
          decodeError("unterminated escape sequence", position)
        end
        if escaped == '"' or escaped == "\\" or escaped == "/" then
          chunks[#chunks + 1] = escaped
          position = position + 2
        elseif escaped == "b" then
          chunks[#chunks + 1] = "\b"
          position = position + 2
        elseif escaped == "f" then
          chunks[#chunks + 1] = "\f"
          position = position + 2
        elseif escaped == "n" then
          chunks[#chunks + 1] = "\n"
          position = position + 2
        elseif escaped == "r" then
          chunks[#chunks + 1] = "\r"
          position = position + 2
        elseif escaped == "t" then
          chunks[#chunks + 1] = "\t"
          position = position + 2
        elseif escaped == "u" then
          local hex = input:sub(position + 2, position + 5)
          if not hex:match("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
            decodeError("invalid unicode escape", position)
          end
          local codepoint = tonumber(hex, 16)
          if codepoint <= 0x7F then
            chunks[#chunks + 1] = string.char(codepoint)
          elseif codepoint <= 0x7FF then
            local b1 = 0xC0 + math.floor(codepoint / 0x40)
            local b2 = 0x80 + (codepoint % 0x40)
            chunks[#chunks + 1] = string.char(b1, b2)
          else
            local b1 = 0xE0 + math.floor(codepoint / 0x1000)
            local b2 = 0x80 + (math.floor(codepoint / 0x40) % 0x40)
            local b3 = 0x80 + (codepoint % 0x40)
            chunks[#chunks + 1] = string.char(b1, b2, b3)
          end
          position = position + 6
        else
          decodeError("unsupported escape sequence", position)
        end
      else
        chunks[#chunks + 1] = char
        position = position + 1
      end
    end

    decodeError("unterminated string", position)
  end

  local function parseNumber()
    local startPos = position

    if input:sub(position, position) == "-" then
      position = position + 1
    end

    local firstDigit = input:sub(position, position)
    if firstDigit == "0" then
      position = position + 1
    elseif firstDigit:match("%d") then
      while input:sub(position, position):match("%d") do
        position = position + 1
      end
    else
      decodeError("invalid number", startPos)
    end

    if input:sub(position, position) == "." then
      position = position + 1
      if not input:sub(position, position):match("%d") then
        decodeError("invalid fractional number", position)
      end
      while input:sub(position, position):match("%d") do
        position = position + 1
      end
    end

    local exponentMarker = input:sub(position, position)
    if exponentMarker == "e" or exponentMarker == "E" then
      position = position + 1
      local sign = input:sub(position, position)
      if sign == "+" or sign == "-" then
        position = position + 1
      end
      if not input:sub(position, position):match("%d") then
        decodeError("invalid exponent", position)
      end
      while input:sub(position, position):match("%d") do
        position = position + 1
      end
    end

    local numberValue = tonumber(input:sub(startPos, position - 1))
    if numberValue == nil then
      decodeError("invalid number conversion", startPos)
    end
    return numberValue
  end

  local function parseLiteral(literal, value)
    if input:sub(position, position + #literal - 1) ~= literal then
      decodeError("invalid literal", position)
    end
    position = position + #literal
    return value
  end

  local function parseArray()
    if input:sub(position, position) ~= "[" then
      decodeError("expected array opening bracket", position)
    end
    position = position + 1
    skipWhitespace()

    local array = {}
    if input:sub(position, position) == "]" then
      position = position + 1
      return array
    end

    while true do
      array[#array + 1] = parseValue()
      skipWhitespace()

      local char = input:sub(position, position)
      if char == "]" then
        position = position + 1
        return array
      end
      if char ~= "," then
        decodeError("expected array separator", position)
      end
      position = position + 1
      skipWhitespace()
    end
  end

  local function parseObject()
    if input:sub(position, position) ~= "{" then
      decodeError("expected object opening brace", position)
    end
    position = position + 1
    skipWhitespace()

    local object = {}
    if input:sub(position, position) == "}" then
      position = position + 1
      return object
    end

    while true do
      if input:sub(position, position) ~= '"' then
        decodeError("expected object key string", position)
      end
      local key = parseString()
      skipWhitespace()
      if input:sub(position, position) ~= ":" then
        decodeError("expected object key separator", position)
      end
      position = position + 1
      skipWhitespace()
      object[key] = parseValue()
      skipWhitespace()

      local char = input:sub(position, position)
      if char == "}" then
        position = position + 1
        return object
      end
      if char ~= "," then
        decodeError("expected object separator", position)
      end
      position = position + 1
      skipWhitespace()
    end
  end

  parseValue = function()
    skipWhitespace()
    local char = input:sub(position, position)
    if char == '"' then
      return parseString()
    end
    if char == "{" then
      return parseObject()
    end
    if char == "[" then
      return parseArray()
    end
    if char == "-" or char:match("%d") then
      return parseNumber()
    end
    if char == "t" then
      return parseLiteral("true", true)
    end
    if char == "f" then
      return parseLiteral("false", false)
    end
    if char == "n" then
      return parseLiteral("null", nil)
    end
    decodeError("unexpected value token", position)
  end

  local decoded = parseValue()
  skipWhitespace()
  if position <= length then
    decodeError("unexpected trailing content", position)
  end
  return decoded
end

function Json.Decode(text)
  return decode(text)
end

return Json
