-- Decodificador JSON minimo en Lua puro.
--
-- Por que esto y no una libreria: el Lua que embebe Hyprland no trae
-- `require` de modulos externos (no hay lua-cjson ni lua-yaml disponibles
-- desde el interprete de la config), asi que cualquier dependencia externa
-- rompe el arranque de la sesion. JSON se decodifica en un archivo corto y
-- auditable; YAML no (necesitaria un parser de verdad).
--
-- Solo implementa `decode` -- la config se escribe a mano, nunca la generamos
-- desde Lua, asi que no hace falta `encode`.
--
-- @author Neoterux

local json = {}

-- `null` no puede mapearse a `nil` porque en Lua eso borra la clave (y deja
-- agujeros en los arrays). Se usa un centinela y quien consume decide.
json.null = setmetatable({}, {
    __tostring = function()
        return "null"
    end,
})

local escapes = {
    ['"'] = '"',
    ["\\"] = "\\",
    ["/"] = "/",
    b = "\b",
    f = "\f",
    n = "\n",
    r = "\r",
    t = "\t",
}

local literals = {
    ["true"] = true,
    ["false"] = false,
    ["null"] = json.null,
}

--- Traduce un offset absoluto a linea/columna, para que los errores de sintaxis
--- sean accionables ("linea 12" en vez de "caracter 341").
local function line_col(str, idx)
    local line, col = 1, 1
    for i = 1, math.min(idx, #str) - 1 do
        if str:sub(i, i) == "\n" then
            line, col = line + 1, 1
        else
            col = col + 1
        end
    end
    return line, col
end

local function fail(str, idx, msg)
    local line, col = line_col(str, idx)
    error(string.format("JSON invalido: %s (linea %d, columna %d)", msg, line, col), 0)
end

local function skip_ws(str, idx)
    local _, stop = str:find("^[ \t\r\n]*", idx)
    return stop + 1
end

--- Codifica un codepoint como UTF-8 a mano, sin depender de la libreria `utf8`
--- (que Hyprland no garantiza tener cargada en el sandbox de la config).
local function utf8_encode(cp)
    if cp < 0x80 then
        return string.char(cp)
    elseif cp < 0x800 then
        return string.char(0xC0 | (cp >> 6), 0x80 | (cp & 0x3F))
    elseif cp < 0x10000 then
        return string.char(0xE0 | (cp >> 12), 0x80 | ((cp >> 6) & 0x3F), 0x80 | (cp & 0x3F))
    end
    return string.char(
        0xF0 | (cp >> 18),
        0x80 | ((cp >> 12) & 0x3F),
        0x80 | ((cp >> 6) & 0x3F),
        0x80 | (cp & 0x3F)
    )
end

local function parse_hex4(str, idx)
    local hex = str:sub(idx, idx + 3)
    if not hex:match("^%x%x%x%x$") then
        fail(str, idx, "escape \\u mal formado")
    end
    return tonumber(hex, 16)
end

local parse_value

local function parse_string(str, idx)
    local out = {}
    local i = idx + 1 -- saltea la comilla de apertura
    while true do
        local char = str:sub(i, i)
        if char == "" then
            fail(str, idx, "string sin cerrar")
        elseif char == '"' then
            return table.concat(out), i + 1
        elseif char == "\\" then
            local code = str:sub(i + 1, i + 1)
            if code == "u" then
                local cp = parse_hex4(str, i + 2)
                i = i + 6
                -- Par subrogado: los BMP-externos vienen partidos en dos \u.
                if cp >= 0xD800 and cp <= 0xDBFF and str:sub(i, i + 1) == "\\u" then
                    local low = parse_hex4(str, i + 2)
                    if low >= 0xDC00 and low <= 0xDFFF then
                        cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                        i = i + 6
                    end
                end
                out[#out + 1] = utf8_encode(cp)
            else
                local mapped = escapes[code]
                if not mapped then
                    fail(str, i, "escape desconocido '\\" .. code .. "'")
                end
                out[#out + 1] = mapped
                i = i + 2
            end
        elseif char == "\n" then
            fail(str, i, "salto de linea sin escapar dentro de un string")
        else
            -- Consume de corrido hasta el proximo caracter interesante, en vez
            -- de agregar byte por byte.
            local chunk_end = str:find('["\\\n]', i) or (#str + 1)
            out[#out + 1] = str:sub(i, chunk_end - 1)
            i = chunk_end
        end
    end
end

local function parse_number(str, idx)
    local _, stop = str:find("^%-?%d+%.?%d*[eE]?[-+]?%d*", idx)
    local literal = str:sub(idx, stop)
    local num = tonumber(literal)
    if not num then
        fail(str, idx, "numero mal formado: '" .. literal .. "'")
    end
    return num, stop + 1
end

local function parse_literal(str, idx)
    for word, value in pairs(literals) do
        if str:sub(idx, idx + #word - 1) == word then
            return value, idx + #word
        end
    end
    fail(str, idx, "valor inesperado")
end

local function parse_array(str, idx)
    local arr = {}
    local i = skip_ws(str, idx + 1)
    if str:sub(i, i) == "]" then
        return arr, i + 1
    end
    while true do
        local value
        value, i = parse_value(str, i)
        arr[#arr + 1] = value
        i = skip_ws(str, i)
        local char = str:sub(i, i)
        if char == "]" then
            return arr, i + 1
        elseif char ~= "," then
            fail(str, i, "se esperaba ',' o ']'")
        end
        i = skip_ws(str, i + 1)
    end
end

local function parse_object(str, idx)
    local obj = {}
    local i = skip_ws(str, idx + 1)
    if str:sub(i, i) == "}" then
        return obj, i + 1
    end
    while true do
        if str:sub(i, i) ~= '"' then
            fail(str, i, "la clave de un objeto debe ser un string")
        end
        local key
        key, i = parse_string(str, i)
        i = skip_ws(str, i)
        if str:sub(i, i) ~= ":" then
            fail(str, i, "se esperaba ':' despues de la clave '" .. key .. "'")
        end
        i = skip_ws(str, i + 1)
        obj[key], i = parse_value(str, i)
        i = skip_ws(str, i)
        local char = str:sub(i, i)
        if char == "}" then
            return obj, i + 1
        elseif char ~= "," then
            fail(str, i, "se esperaba ',' o '}'")
        end
        i = skip_ws(str, i + 1)
    end
end

parse_value = function(str, idx)
    local char = str:sub(idx, idx)
    if char == "{" then
        return parse_object(str, idx)
    elseif char == "[" then
        return parse_array(str, idx)
    elseif char == '"' then
        return parse_string(str, idx)
    elseif char == "-" or char:match("%d") then
        return parse_number(str, idx)
    elseif char == "" then
        fail(str, idx, "documento vacio")
    end
    return parse_literal(str, idx)
end

--- Decodifica un documento JSON completo.
--- Lanza error (con linea/columna) si el texto no es JSON valido.
--- @param str string
--- @return any
function json.decode(str)
    if type(str) ~= "string" then
        error("json.decode espera un string, recibio " .. type(str), 0)
    end
    local idx = skip_ws(str, 1)
    local value, stop = parse_value(str, idx)
    stop = skip_ws(str, stop)
    if stop <= #str then
        fail(str, stop, "basura despues del valor de nivel superior")
    end
    return value
end

return json
