-- Layout "stacked-dwindle": hibrido scroll + dwindle.
--
-- Un workspace con este layout se divide en PAGINAS (sub-workspaces). Solo
-- una se ve a la vez; adentro de cada pagina las ventanas se tilean en
-- espiral estilo dwindle (1 ventana = pantalla completa, p.ej. VSCode; 3
-- terminales = arbol). Cambiar de pagina desliza todo verticalmente, como
-- scrollear.
--
-- Se activa por workspace con la regla `layout = "lua:stacked-dwindle"` (el
-- prefijo `lua:` lo agrega Hyprland a todo layout registrado desde Lua --
-- verificado en vivo, con el nombre pelado la regla no lo encuentra). El
-- picker de layouts de la barra (quickshell WorkspaceLayout.qml) ya lo ofrece.
--
-- Mensajes (`hl.dsp.layout("<msg>")`, ver binds/init.lua):
--   page next|prev        -- pagina siguiente/anterior, dando la vuelta
--   page down|up          -- sin dar la vuelta (para la rueda); `down` desde
--                            la ultima pagina abre una nueva vacia
--   page new              -- abrir una pagina nueva vacia al final e ir ahi
--   page <n>              -- ir a la pagina n
--   togglesplit           -- invertir el corte entre la ventana activa y su
--                            vecina (lado a lado <-> apiladas), como en
--                            dwindle; es lo que hace SUPER + click del medio
--   movepage <de> <a>     -- reordenar: la pagina <de> pasa a la posicion
--                            <a> (lo usa el drawer de PageIndicator.qml)
--   movetopage next|prev  -- mandar la ventana activa a la pagina de al
--                            lado; pasando el borde crea una pagina nueva
--   movetopage new        -- mandar la ventana activa a una pagina nueva
--
-- Las paginas NO visibles se colocan fuera del monitor, arriba o abajo, y
-- no a los costados: los monitores de esta config estan lado a lado, asi
-- que un corrimiento horizontal dibujaria la pagina oculta en el monitor
-- vecino. Verificado en vivo que una caja fuera de `ctx.area` no se ve y
-- no la reclama otro monitor. Como `place()` anima, el cambio de pagina
-- se desliza con la animacion `windows` de lookandfeel.
--
-- Paginas vacias: la pagina VISIBLE puede estar vacia (recien creada con
-- `page new`), y lo que se abra ahi cae en ella. Apenas se sale de una
-- pagina vacia, desaparece. Mientras se esta en una pagina vacia el foco de
-- teclado sigue en la ventana (ya oculta) de donde se vino: Hyprland no
-- tiene forma de "no enfocar nada" desde el layout.
--
-- El estado de cada workspace (pagina visible / cantidad) se publica en
-- $XDG_RUNTIME_DIR/hyprland-neo/stacked-dwindle.json para el indicador de
-- Quickshell (bar/PageIndicator.qml). Solo se reescribe cuando cambia.
--
-- OJO: el estado (que ventana esta en que pagina) vive en memoria de Lua.
-- Un `hyprctl reload` lo borra y todas las ventanas caen en la pagina 1.

local M = {}

-- Espacio extra entre paginas para que ni el borde ni la sombra de una
-- pagina oculta se asomen por el filo del monitor.
local PAGE_SPACING = 64

-- state[ws_id] = {
--   active = <indice de pagina visible>,
--   list   = { { stable_id, ... }, ... },  -- orden de insercion por pagina
--   last   = { [pagina] = stable_id }      -- ultima ventana enfocada por pagina
--   fresh  = true|nil  -- la pagina visible se creo vacia a proposito
-- }
local state = {}
-- stable_id -> address, para poder enfocar por selector "address:..."
local addresses = {}
-- stable_id -> ws_id, para resolver la pagina desde el evento de foco
local owner = {}
-- stable_id -> class, para que el indicador dibuje el icono de cada app
local classes = {}
-- stable_id -> true: el corte que hace esa ventana va al reves de lo que
-- pide el lado mas largo (lo prende/apaga `togglesplit`).
local flipped = {}

local function wsState(ws)
    local s = state[ws]
    if not s then
        s = { active = 1, list = { {} }, last = {} }
        state[ws] = s
    end
    return s
end

local function findPage(s, id)
    for p, page in ipairs(s.list) do
        for i, wid in ipairs(page) do
            if wid == id then
                return p, i
            end
        end
    end
    return nil
end

local function gapsIn()
    local g = hl.get_config("general.gaps_in")
    if type(g) == "table" then
        return (g.left or 0) + (g.right or 0)
    end
    return (tonumber(g) or 0) * 2
end

-- Espiral dwindle: cada ventana se queda con la mitad de lo que queda,
-- cortando por el lado mas largo (o el otro, si `togglesplit` la invirtio);
-- la ultima se lleva el resto.
local function spiral(box, page, gap)
    local n = #page
    local boxes = {}
    local rest = { x = box.x, y = box.y, w = box.w, h = box.h }
    for i = 1, n do
        local sideBySide = rest.w >= rest.h
        if flipped[page[i]] then
            sideBySide = not sideBySide
        end
        if i == n then
            boxes[i] = rest
        elseif sideBySide then
            local w = (rest.w - gap) / 2
            boxes[i] = { x = rest.x, y = rest.y, w = w, h = rest.h }
            rest = { x = rest.x + w + gap, y = rest.y, w = rest.w - w - gap, h = rest.h }
        else
            local h = (rest.h - gap) / 2
            boxes[i] = { x = rest.x, y = rest.y, w = rest.w, h = h }
            rest = { x = rest.x, y = rest.y + h + gap, w = rest.w, h = rest.h - h - gap }
        end
    end
    return boxes
end

local function workspaceOf(ctx)
    local t = ctx.targets[1]
    local ws = t and t.window and t.window.workspace
    return ws and ws.id or nil
end

-- Sincroniza el estado con las ventanas reales: poda las que se fueron,
-- elimina paginas vacias y mete las nuevas en la pagina visible.
local function sync(s, targets)
    local present = {}
    for _, t in ipairs(targets) do
        present[t.window.stable_id] = true
    end

    local list, active = {}, s.active
    for p, page in ipairs(s.list) do
        local kept = {}
        for _, id in ipairs(page) do
            if present[id] then
                kept[#kept + 1] = id
            end
        end
        if #kept > 0 or p == s.active then
            list[#list + 1] = kept
        elseif p < s.active then
            active = active - 1
        end
    end
    s.list, s.active = list, math.max(1, math.min(active, #list))

    for _, t in ipairs(targets) do
        local id = t.window.stable_id
        if not findPage(s, id) then
            table.insert(s.list[s.active], id)
            s.fresh = nil
        end
    end

    -- La pagina visible puede haber quedado vacia (se cerro su ultima
    -- ventana): se descarta y se muestra la vecina, salvo que sea la unica.
    -- Una recien creada con `page new` (fresh) se respeta hasta salir de
    -- ella o meterle una ventana.
    if #s.list[s.active] == 0 and #s.list > 1 and not s.fresh then
        table.remove(s.list, s.active)
        s.active = math.min(s.active, #s.list)
    end
end

local STATE_DIR = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hyprland-neo"
local STATE_PATH = STATE_DIR .. "/stacked-dwindle.json"
local lastExport = nil

-- {"<ws>":{"active":n,"count":m,"pages":[["kitty","code-oss"],[...]]},...}.
-- Se escribe a mano: el Lua embebido no trae encoder JSON. Las clases van
-- escapadas por las dudas, aunque en la practica son identificadores.
local function jsonString(v)
    return '"' .. tostring(v):gsub('[%c"\\]', function(c)
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end

local function exportState()
    local ids = {}
    for ws in pairs(state) do
        ids[#ids + 1] = ws
    end
    table.sort(ids)
    local parts = {}
    for _, ws in ipairs(ids) do
        local s = state[ws]
        local pages = {}
        for p, page in ipairs(s.list) do
            local apps = {}
            for i, id in ipairs(page) do
                apps[i] = jsonString(classes[id] or "")
            end
            pages[p] = "[" .. table.concat(apps, ",") .. "]"
        end
        parts[#parts + 1] = string.format('"%d":{"active":%d,"count":%d,"pages":[%s]}',
            ws, s.active, #s.list, table.concat(pages, ","))
    end
    local json = "{" .. table.concat(parts, ",") .. "}\n"
    if json == lastExport then
        return
    end
    local fh = io.open(STATE_PATH, "w")
    if not fh then
        os.execute("mkdir -p '" .. STATE_DIR .. "'")
        fh = io.open(STATE_PATH, "w")
    end
    if fh then
        fh:write(json)
        fh:close()
        lastExport = json
    end
end

local function recalculate(ctx)
    local ws = workspaceOf(ctx)
    if not ws then
        return
    end
    local s = wsState(ws)

    local byId = {}
    for _, t in ipairs(ctx.targets) do
        local id = t.window.stable_id
        byId[id] = t
        addresses[id] = t.window.address
        owner[id] = ws
        classes[id] = t.window.class
    end
    sync(s, ctx.targets)

    local a, gap = ctx.area, gapsIn()
    for p, page in ipairs(s.list) do
        local dy = (p - s.active) * (a.h + PAGE_SPACING)
        local box = { x = a.x, y = a.y + dy, w = a.w, h = a.h }
        for i, b in ipairs(spiral(box, page, gap)) do
            byId[page[i]]:place(b)
        end
    end
    exportState()
end

-- Enfocar se difiere un tick: despachar desde adentro de layout_msg
-- reentraria en el layout mientras Hyprland todavia esta procesando el
-- mensaje.
local function focusLater(id)
    local addr = id and addresses[id]
    if not addr then
        return
    end
    hl.timer(function()
        hl.dispatch(hl.dsp.focus({ window = "address:" .. tostring(addr) }))
    end, { timeout = 1, type = "oneshot" })
end

local function showPage(s, p)
    s.active = p
    s.fresh = nil
    local page = s.list[p]
    local target = s.last[p]
    if not target or findPage(s, target) ~= p then
        target = page[1]
    end
    focusLater(target)
end

local function movetopage(s, dir)
    local win = hl.get_active_window()
    if not win then
        return
    end
    local id = win.stable_id
    local from, idx = findPage(s, id)
    if not from then
        return
    end
    table.remove(s.list[from], idx)

    local to
    if dir == "new" then
        to = #s.list + 1
        s.list[to] = {}
    elseif dir == "next" then
        to = from + 1
        if to > #s.list then
            s.list[to] = {}
        end
    else
        to = from - 1
        if to < 1 then
            table.insert(s.list, 1, {})
            to, from = 1, from + 1
        end
    end
    table.insert(s.list[to], id)

    -- Si la pagina de origen quedo vacia se elimina ya, para que el
    -- indice `to` siga apuntando a la pagina correcta despues.
    if #s.list[from] == 0 then
        table.remove(s.list, from)
        if from < to then
            to = to - 1
        end
    end
    s.active = to
    s.fresh = nil
    s.last[to] = id
    focusLater(id)
end

local function newPage(s)
    -- Si ya se esta en una pagina vacia, no se apilan mas vacias.
    if #s.list[s.active] == 0 then
        return
    end
    s.list[#s.list + 1] = {}
    s.active = #s.list
    s.fresh = true
end

-- Reordena: la pagina `from` pasa a la posicion `to`. La pagina visible
-- sigue siendo la misma (su indice cambia con ella) y `last` se remapea,
-- porque esta indexado por posicion.
local function movePage(s, from, to)
    local n = #s.list
    if not from or not to or from < 1 or from > n or to < 1 or to > n then
        return false
    end
    if from == to then
        return true
    end
    local order = {}
    for i = 1, n do
        order[i] = i
    end
    table.insert(order, to, table.remove(order, from))
    local list, last, active = {}, {}, s.active
    for newPos, oldPos in ipairs(order) do
        list[newPos] = s.list[oldPos]
        last[newPos] = s.last[oldPos]
        if oldPos == s.active then
            active = newPos
        end
    end
    s.list, s.last, s.active = list, last, active
    return true
end

local function layoutMsg(ctx, msg)
    -- Sin ventanas tileadas (workspace vacio, o todo flotante -- p.ej. las
    -- kitty que float-kitty deja flotando) no hay paginas que mover: se
    -- ignora en silencio. Devolver `false` hace que Hyprland lo reporte
    -- como error ("lua layout lua:stacked-dwindle rejected layoutmsg").
    local ws = workspaceOf(ctx)
    if not ws then
        return true
    end
    local s = wsState(ws)
    sync(s, ctx.targets)

    local cmd, arg, arg2 = msg:match("^%s*(%S+)%s*(%S*)%s*(%S*)")
    local n = #s.list
    if cmd == "page" then
        local p
        if arg == "next" then
            p = s.active % n + 1
        elseif arg == "prev" then
            p = (s.active - 2) % n + 1
        elseif arg == "down" and s.active == n then
            newPage(s)
            return true
        elseif arg == "new" then
            newPage(s)
            return true
        elseif arg == "down" then
            p = s.active + 1
        elseif arg == "up" then
            p = math.max(s.active - 1, 1)
        else
            p = tonumber(arg)
        end
        if not p or p < 1 or p > n then
            return "stacked-dwindle: pagina invalida '" .. tostring(arg) .. "'"
        end
        if p ~= s.active then
            showPage(s, p)
        end
        return true
    elseif cmd == "movetopage" then
        if arg ~= "next" and arg ~= "prev" and arg ~= "new" then
            return "stacked-dwindle: movetopage espera next|prev|new"
        end
        movetopage(s, arg)
        return true
    elseif cmd == "togglesplit" then
        -- El corte entre la ventana i y el resto lo hace la ventana i; la
        -- ultima no corta nada, asi que para ella se invierte el de la
        -- anterior (el que la separa de su vecina). Con una sola ventana en
        -- la pagina no hay corte que invertir: no se hace nada.
        local win = hl.get_active_window()
        local p, i = findPage(s, win and win.stable_id)
        if p and #s.list[p] > 1 then
            local page = s.list[p]
            local id = page[math.min(i, #page - 1)]
            flipped[id] = not flipped[id] or nil
        end
        return true
    elseif cmd == "movepage" then
        if not movePage(s, tonumber(arg), tonumber(arg2)) then
            return "stacked-dwindle: movepage espera <de> <a> entre 1 y " .. n
        end
        return true
    elseif cmd == "sync" then
        return true
    end
    return "stacked-dwindle: mensaje desconocido '" .. msg .. "'"
end

-- Si el foco cae en una ventana de una pagina oculta (alt-tab, activacion
-- desde una notificacion, `focus` por direccion), la pagina se trae a la
-- vista. De paso se recuerda la ultima ventana enfocada de cada pagina.
local function onActive(win)
    win = win or hl.get_active_window()
    if not win then
        return
    end
    local id = win.stable_id
    local ws = owner[id]
    local s = ws and state[ws]
    if not s then
        return
    end
    local p = findPage(s, id)
    if not p then
        return
    end
    s.last[p] = id
    if p ~= s.active then
        s.active = p
        s.fresh = nil
        hl.dispatch(hl.dsp.layout("sync"))
    end
end

-- Para los binds: manda `msg` al layout solo si el workspace activo usa
-- "lua:stacked-dwindle". En cualquier otro layout el mensaje no existe y Hyprland lo
-- reporta como error ("Unknown dwindle layoutmsg: ..."), asi que ahi el
-- bind no hace nada.
function M.msg(msg)
    return function()
        local ws = hl.get_active_workspace()
        if ws and ws.tiled_layout == "lua:stacked-dwindle" then
            hl.dispatch(hl.dsp.layout(msg))
        end
    end
end

function M.setup()
    hl.layout.register("stacked-dwindle", {
        recalculate = recalculate,
        layout_msg = layoutMsg,
    })
    hl.on("window.active", function(...)
        local ok, err = pcall(onActive, (select(1, ...)))
        if not ok then
            print("[stacked-dwindle] window.active: " .. tostring(err))
        end
    end)
end

return M
