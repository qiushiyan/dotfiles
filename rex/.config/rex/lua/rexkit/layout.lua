-- rexkit.layout: geometry from a session.view result, with no calls of its
-- own. A view lists windows (the tabs) in tab order, each with layers; a
-- layer's blocks carry normalized rects (0..1 of the window).

local M = {}

-- Every block of a window's tiled layer, with its rect.
function M.tiled(window)
  local out = {}
  for _, layer in ipairs((window and window.layers) or {}) do
    if layer.kind == "tiled" then
      for _, b in ipairs(layer.blocks or {}) do out[#out + 1] = b end
    end
  end
  return out
end

-- Every block of a window, floating layers too.
function M.blocks(window)
  local out = {}
  for _, layer in ipairs((window and window.layers) or {}) do
    for _, b in ipairs(layer.blocks or {}) do out[#out + 1] = b end
  end
  return out
end

-- The window of a view that holds BLOCK_ID in its tiled layer, else nil.
function M.window_of(view, block_id)
  for _, w in ipairs((view and view.windows) or {}) do
    for _, b in ipairs(M.tiled(w)) do
      if b.block_id == block_id then return w end
    end
  end
end

-- The position of WINDOW_ID in the view's tab order, else nil.
function M.index_of(view, window_id)
  for i, w in ipairs((view and view.windows) or {}) do
    if w.window_id == window_id then return i end
  end
end

-- The block beside BLOCK_ID in DIRECTION (left, right, up, down) within its
-- window: of the blocks that touch that edge and overlap it across, the one
-- that overlaps most. nil at the window's edge. tmux's pane_at_right, from
-- the rects session.view reports.
local EPS = 1e-3

local function overlap(a0, a1, b0, b1) return math.min(a1, b1) - math.max(a0, b0) end

local EDGE = {
  right = function(me, r) return math.abs(r.x - (me.x + me.w)) < EPS, overlap(me.y, me.y + me.h, r.y, r.y + r.h) end,
  left = function(me, r) return math.abs(r.x + r.w - me.x) < EPS, overlap(me.y, me.y + me.h, r.y, r.y + r.h) end,
  down = function(me, r) return math.abs(r.y - (me.y + me.h)) < EPS, overlap(me.x, me.x + me.w, r.x, r.x + r.w) end,
  up = function(me, r) return math.abs(r.y + r.h - me.y) < EPS, overlap(me.x, me.x + me.w, r.x, r.x + r.w) end,
}

function M.neighbor(view, block_id, direction)
  local edge = EDGE[direction]
  local rects = M.tiled(M.window_of(view, block_id))
  local me
  for _, b in ipairs(rects) do if b.block_id == block_id then me = b.rect end end
  if not (edge and me) then return nil end
  local best, best_overlap = nil, 0
  for _, b in ipairs(rects) do
    if b.block_id ~= block_id then
      local touches, across = edge(me, b.rect)
      if touches and across > best_overlap then best, best_overlap = b.block_id, across end
    end
  end
  return best
end

return M
