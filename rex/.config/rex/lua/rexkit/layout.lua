-- rexkit.layout: geometry from a session.view result, with no calls of its
-- own. A view lists windows (the tabs) in tab order, each with layers; a
-- layer's layout tree carries the rects, as [x, y, w, h] fractions of the
-- window, and its blocks list carries none.

local M = {}

-- The leaves of LAYER's layout tree in layout order, before then after down
-- each split (the order tmux numbers panes in), appended to OUT as
-- { block_id, rect = { x, y, w, h } }.
local function leaves(layer, out)
  local function walk(node)
    if not node then return end
    if node.split then
      walk(node.split.before)
      walk(node.split.after)
    elseif node.block_id then
      local r = node.rect or {}
      out[#out + 1] = { block_id = node.block_id, rect = { x = r[1], y = r[2], w = r[3], h = r[4] } }
    end
  end
  walk(layer.layout)
  return out
end

-- Every block of a window's tiled layer, with its rect, in layout order.
function M.tiled(window)
  local out = {}
  for _, layer in ipairs((window and window.layers) or {}) do
    if layer.kind == "tiled" then leaves(layer, out) end
  end
  return out
end

-- The window of a view that places BLOCK_ID in any layer, and the block's
-- rect there; nil when no window does.
function M.placement(view, block_id)
  for _, w in ipairs((view and view.windows) or {}) do
    for _, layer in ipairs(w.layers or {}) do
      for _, b in ipairs(leaves(layer, {})) do
        if b.block_id == block_id then return w, b.rect end
      end
    end
  end
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
