local M = {}

function M.setup()
    hl.monitor({
        output = "DP-1",
        mode = "2560x1440@180",
        position = "0x0",
        scale = 1,
    })

    hl.monitor({
        output = "DP-3",
        mode = "1920x1080@144",
        position = "auto-left",
        scale = 1,
    })

    hl.workspace_rule({
        workspace = "1",
        monitor = "DP-1",
    })
end

return M
