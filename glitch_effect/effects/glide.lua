MIN_RADIUS = 10
MAX_RADIUS = 20
local SPEED = 0.5
local RADIUS = 20
local BASE_WIDTH, BASE_HEIGHT = 800, 500
local RANDOM_MARGIN = 100

return function(c, ctx, s)
  s.glide_radius = RADIUS
  s.base_x = c.x
  s.base_y = c.y
  local scr = c.screen and c.screen.geometry
  s.glide_phase = s.glide_phase or math.random() * 2 * math.pi
  local normalized_rms = (ctx.rms * 2) - 1 -- Assuming ctx.rms is in the range [0, 1]
        y = math.random(scr.y + RANDOM_MARGIN, scr.y + scr.height - RANDOM_MARGIN),

  -- if ctx.rms ~= 0 then
  s.glide_speed = SPEED * normalized_rms
  -- else
  --   s.glide_speed = (SPEED * 2) - 1
  -- end

  -- if ctx.mfcc0 ~= 0 then
  s.glide_radius = RADIUS + math.min(MIN_RADIUS, math.max(MAX_RADIUS, ctx.mfcc0))
  -- else
  --   s.glide_radius = RADIUS
  -- end

  -- Modulate phase using an audio signal (e.g., ctx.mfcc0)
  local modulation = ctx.contrast ~= 0 and ctx.contrast or 1
  s.glide_phase = (s.glide_phase + s.glide_speed * modulation) % (2 * math.pi)

  local w = c.width
  local h = c.height
  local glide_x = math.floor(s.base_x + s.glide_radius * math.cos(s.glide_phase))
  local glide_y = math.floor(s.base_y + s.glide_radius * math.sin(s.glide_phase))
  local new_x, new_y = glide_x, glide_y

  -- Clamp to screen
  new_x = math.max(scr.x, math.min(new_x, scr.x + scr.width - w))
  new_y = math.max(scr.y, math.min(new_y, scr.y + scr.height - h))
  local geom = c:geometry()
  if geom.x ~= new_x or geom.y ~= new_y then
    c:geometry { x = new_x, y = new_y }
  end
end
