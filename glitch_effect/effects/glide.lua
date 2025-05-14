MIN_RADIUS = 10
MAX_RADIUS = 20
local SPEED = 0.5
local RADIUS = 20
local BASE_WIDTH, BASE_HEIGHT = 800, 500

return function(c, ctx, s)
    s.base_x = s.base_x or c.x
    s.base_y = s.base_y or c.y
    local scr = c.screen and c.screen.geometry 
    s.glide_phase = s.glide_phase or math.random() * 2 * math.pi
    s.glide_center = s.glide_center or {
        x = math.random(scr.x + RANDOM_MARGIN, scr.x + scr.width - RANDOM_MARGIN),
        y = math.random(scr.y + RANDOM_MARGIN, scr.y + scr.height - RANDOM_MARGIN),
    }
    s.glide_radius = RADIUS + (math.abs(ctx.mfcc0)) 
    s.glide_speed = SPEED * (ctx.rms * 10)

    s.glide_phase = (s.glide_phase + s.glide_speed * (ctx.tick or 0.1)) % (2 * math.pi)


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
