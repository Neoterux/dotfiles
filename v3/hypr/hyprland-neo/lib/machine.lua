-- Carga del perfil de maquina (`hyprland-neo/machines/<hostname>.json`).
--
-- Este repo de dotfiles se comparte entre varias maquinas y lo que cambia
-- entre ellas no es la config en si, sino los *datos*: que outputs existen,
-- como se ordenan, en que monitor arranca cada workspace, y si el teclado es
-- un split (corne) o uno completo. Todo eso vive en un JSON por maquina y este
-- modulo lo resuelve, valida y normaliza en algo que `hl.*` pueda consumir
-- directo.
--
-- Orden de resolucion:
--   1. $HYPRNEO_MACHINE  -> machines/$HYPRNEO_MACHINE.json  (util para probar
--                           el perfil de otra maquina sin renombrar nada)
--   2. hostname          -> machines/<hostname>.json
--   3. machines/default.json
--
-- Si el JSON elegido no existe o no parsea, se cae a un perfil vacio seguro
-- (Hyprland autodetecta los monitores) y se notifica en pantalla en vez de
-- tumbar la sesion entera: una config de monitores rota deja la maquina sin
-- imagen, y eso es mucho peor que un layout equivocado.
--
-- @author Neoterux

local json = require('hyprland-neo/lib/json')

local M = {}

-- Claves del objeto `monitor` que consume este modulo y por lo tanto NO se
-- reenvian a `hl.monitor`. El resto pasa tal cual, asi que cualquier campo de
-- HL.MonitorSpec (transform, vrr, mirror, bitdepth, cm, ...) funciona en el
-- JSON sin tocar este archivo.
local MONITOR_META_KEYS = {
    workspaces = true,
    default_workspace = true,
    comment = true,
    note = true,
}

-- Alias aceptados para `keyboard.layout`, para no tener que recordar el nombre
-- exacto al agregar una maquina nueva.
local KEYBOARD_ALIASES = {
    split = "split",
    corne = "split",
    ergo = "split",
    standard = "standard",
    normal = "standard",
    full = "standard",
    tkl = "standard",
}

local function is_ignored_key(key)
    return MONITOR_META_KEYS[key] or key:sub(1, 1) == "_" or key:sub(1, 1) == "$"
end

local function trim(str)
    return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Convierte un id de workspace a la string que espera `hl.workspace_rule`.
--- JSON no distingue enteros de flotantes, asi que un `4.0` en el archivo
--- llegaria como "4.0" con un `tostring` pelado -- y Hyprland lo rechaza.
local function workspace_id(value)
    if type(value) == "number" then
        local int = math.tointeger(value)
        if int then
            return tostring(int)
        end
    end
    return tostring(value)
end

local function read_file(path)
    local fh = io.open(path, "r")
    if not fh then
        return nil
    end
    local content = fh:read("*a")
    fh:close()
    return content
end

--- Directorio `hyprland-neo/` (donde cuelga `machines/`).
--- Se deduce de la ruta de *este* archivo para que el repo siga funcionando si
--- se clona en otro lado o se prueba desde un checkout aparte, con los paths
--- XDG habituales como respaldo.
local function module_dir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        -- .../hyprland-neo/lib/machine.lua -> .../hyprland-neo
        local dir = source:sub(2):match("^(.*)/lib/machine%.lua$")
        if dir then
            return dir
        end
    end
    local xdg = os.getenv("XDG_CONFIG_HOME")
    if xdg and xdg ~= "" then
        return xdg .. "/hypr/hyprland-neo"
    end
    return (os.getenv("HOME") or "~") .. "/.config/hypr/hyprland-neo"
end

--- Hostname de la maquina, en minusculas (los nombres de archivo son
--- case-sensitive y no vale la pena pelear con "GMachine" vs "gmachine").
local function hostname()
    local content = read_file("/etc/hostname")
    if content then
        local name = trim(content)
        if name ~= "" then
            return name:lower()
        end
    end

    local env = os.getenv("HOSTNAME") or os.getenv("HOST")
    if env and env ~= "" then
        return env:lower()
    end

    local pipe = io.popen("hostname 2>/dev/null")
    if pipe then
        local out = pipe:read("*l")
        pipe:close()
        if out and trim(out) ~= "" then
            return trim(out):lower()
        end
    end

    return nil
end

--- Normaliza una entrada de `monitor.workspaces`.
--- Acepta el atajo `3` / `"3"` (equivale a `{ "id": 3 }`) o el objeto completo
--- con cualquier campo de HL.WorkspaceRuleSpec.
local function normalize_workspace(entry, output, warn)
    local rule
    if type(entry) == "number" or type(entry) == "string" then
        rule = { workspace = workspace_id(entry) }
    elseif type(entry) == "table" then
        rule = {}
        for key, value in pairs(entry) do
            if not is_ignored_key(key) and value ~= json.null then
                rule[key] = value
            end
        end
        local id = rule.id or rule.workspace
        rule.id = nil
        if id == nil then
            warn(string.format("workspace sin 'id' en el monitor '%s', se ignora", output))
            return nil
        end
        rule.workspace = workspace_id(id)
    else
        warn(string.format("workspace de tipo %s en el monitor '%s', se ignora", type(entry), output))
        return nil
    end

    rule.monitor = rule.monitor or output
    return rule
end

local function normalize_monitor(entry, warn)
    if type(entry) ~= "table" then
        warn("cada elemento de 'monitors' debe ser un objeto, se ignora uno de tipo " .. type(entry))
        return nil
    end
    if type(entry.output) ~= "string" or entry.output == "" then
        warn("hay un monitor sin 'output', se ignora")
        return nil
    end

    local spec = {}
    for key, value in pairs(entry) do
        if not is_ignored_key(key) and value ~= json.null then
            spec[key] = value
        end
    end

    local rules = {}
    for _, ws in ipairs(entry.workspaces or {}) do
        local rule = normalize_workspace(ws, entry.output, warn)
        if rule then
            rules[#rules + 1] = rule
        end
    end

    -- `default_workspace` es azucar: marca `default = true` en la regla de ese
    -- workspace, creandola si el workspace no estaba listado. Es el "workspace
    -- inicial" del monitor -- el que Hyprland abre ahi al arrancar.
    local initial = entry.default_workspace
    if initial ~= nil and initial ~= json.null then
        initial = workspace_id(initial)
        local found = false
        for _, rule in ipairs(rules) do
            if rule.workspace == initial then
                rule.default = true
                found = true
                break
            end
        end
        if not found then
            rules[#rules + 1] = { workspace = initial, monitor = entry.output, default = true }
        end
    end

    return { spec = spec, workspace_rules = rules }
end

local function normalize(raw, name, source, warnings)
    local function warn(msg)
        warnings[#warnings + 1] = msg
    end

    if type(raw) ~= "table" then
        warn("el perfil debe ser un objeto JSON")
        raw = {}
    end

    local profile = {
        name = type(raw.name) == "string" and raw.name or name,
        source = source,
        monitors = {},
        workspace_rules = {},
        warnings = warnings,
    }

    -- Teclado: define si las binds de workspace usan el esquema del split
    -- (numeros en capa, ver binds/init.lua) o el clasico.
    local keyboard = type(raw.keyboard) == "table" and raw.keyboard or {}
    local layout = type(keyboard.layout) == "string" and KEYBOARD_ALIASES[keyboard.layout:lower()] or nil
    if keyboard.layout ~= nil and layout == nil then
        warn(string.format("keyboard.layout '%s' desconocido, se usa 'standard'", tostring(keyboard.layout)))
    end
    layout = layout or "standard"
    profile.keyboard = { layout = layout, is_split = layout == "split" }

    for _, entry in ipairs(raw.monitors or {}) do
        local monitor = normalize_monitor(entry, warn)
        if monitor then
            profile.monitors[#profile.monitors + 1] = monitor.spec
            for _, rule in ipairs(monitor.workspace_rules) do
                profile.workspace_rules[#profile.workspace_rules + 1] = rule
            end
        end
    end

    -- Reglas sueltas, para lo que no cuelga de un monitor concreto (workspaces
    -- con layout propio, `on_created_empty`, etc.).
    for _, entry in ipairs(raw.workspace_rules or {}) do
        local rule = normalize_workspace(entry, "", warn)
        if rule then
            if rule.monitor == "" then
                rule.monitor = nil
            end
            profile.workspace_rules[#profile.workspace_rules + 1] = rule
        end
    end

    return profile
end

--- Reporta problemas de carga. Va a la notificacion de Hyprland (visible sin
--- salir de la sesion) y al stdout, que en la practica termina en la tty desde
--- la que arranco Hyprland.
local function report(profile)
    if #profile.warnings == 0 then
        return
    end
    for _, msg in ipairs(profile.warnings) do
        print("[hyprland-neo/machine] " .. msg)
    end
    if hl and hl.notification and hl.notification.create then
        pcall(hl.notification.create, {
            text = "hyprland-neo: perfil de maquina con problemas -- " .. profile.warnings[1],
            timeout = 10,
        })
    end
end

local cached

--- Devuelve el perfil de la maquina actual (cacheado por sesion de config).
--- @return table perfil normalizado: { name, source, keyboard, monitors, workspace_rules, warnings }
function M.get()
    if cached then
        return cached
    end

    local dir = module_dir() .. "/machines"
    local candidates = {}
    local override = os.getenv("HYPRNEO_MACHINE")
    if override and override ~= "" then
        candidates[#candidates + 1] = override
    end
    local host = hostname()
    if host then
        candidates[#candidates + 1] = host
    end
    candidates[#candidates + 1] = "default"

    local warnings = {}
    for _, name in ipairs(candidates) do
        local path = dir .. "/" .. name .. ".json"
        local content = read_file(path)
        if content then
            local ok, raw = pcall(json.decode, content)
            if ok then
                cached = normalize(raw, name, path, warnings)
                report(cached)
                return cached
            end
            warnings[#warnings + 1] = string.format("%s.json no parsea: %s", name, tostring(raw))
        end
    end

    warnings[#warnings + 1] = string.format(
        "no se encontro ningun perfil en %s (probados: %s); Hyprland autodetecta los monitores",
        dir,
        table.concat(candidates, ", ")
    )
    cached = normalize({}, host or "unknown", nil, warnings)
    report(cached)
    return cached
end

return M
