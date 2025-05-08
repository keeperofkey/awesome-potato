local gears = require("gears")
local awful = require("awful")

local M = {}
local effects = {}
local enabled = {}
local state = {}
local timer = nil

-- Register an effect
function M.register_effect(name, fn)
    effects[name] = fn
end

-- Enable/disable effects
function M.enable_effect(name) enabled[name] = true end
function M.disable_effect(name) enabled[name] = nil end

-- Per-client, per-effect state
local function get_state(c, effect)
    state[c.window] = state[c.window] or {}
    state[c.window][effect] = state[c.window][effect] or {}
    return state[c.window][effect]
end

local function cleanup_state()
    local valid = {}
    for _, c in ipairs(client.get()) do valid[c.window] = true end
    for k in pairs(state) do
        if not valid[k] then
            state[k] = nil
        end
    end
end

-- Main tick function: poll signals, run effects
function M.start(context_fn, tick)
    if timer then return end
    timer = gears.timer({
        timeout = tick or 0.1,
        autostart = true,
        call_now = true,
        callback = function()
            cleanup_state()
            local ctx = context_fn and context_fn() or {}
            for name in pairs(enabled) do
                local effect = effects[name]
                if effect then
                    for _, c in ipairs(client.get()) do
                        if c:isvisible() and not c.minimized then
                            effect(c, ctx, get_state(c, name))
                        end
                    end
                end
            end
        end,
    })
end

function M.stop()
    if timer then timer:stop() timer = nil end
    state = {}
end

function M.is_effect_enabled(name)
    return enabled[name] and true or false
end

return M
