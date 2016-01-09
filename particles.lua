local class = require 'middleclass'
require 'utilities'
draw_count = 0 -- each object gets a new index number, to prevent overwriting

--[[Crazy Love2D! So confusing!
    Example:postRepeatFX(
    self.center, -- no need to change
    self.pos[2], -- no need to change
    -100, -- horizontal shift
    self.sprite_size[2], -- vertical shift
    self.facing) -- no need to change
]]


--[[---------------------------------------------------------------------------
                              PARTICLE / FX CLASS
-----------------------------------------------------------------------------]]   
Particle = class('Particle')
function Particle:initialize(image, image_size, sprite_size, time_per_frame, sound, h_center, v_center)
  self.image = image
  self.image_size = {image:getDimensions()}
  self.sprite_size = sprite_size
  self.width = sprite_size[1]
  self.height = sprite_size[2]
  self.center = sprite_size[1] / 2
  self.hitbox = hitbox_table
  self.sound = sound
  self.total_frames = image_size[1] / sprite_size[1]
  self.time_per_frame = time_per_frame
  self.total_time = time_per_frame * self.total_frames
  if h_center then self.h_adjust = self.width / 2 else self.h_adjust = 0 end
  if v_center then self.v_adjust = self.height / 2 else self.v_adjust = 0 end
end

function Particle:getDrawable(image_index, pos_h, pos_v, scale_x, scale_y, RGBTable)
  local quad = love.graphics.newQuad(image_index * self.width, 0,
    self.width, self.height, self.image_size[1], self.image_size[2])
  return {self.image, 
    quad, 
    pos_h + self.center,
    pos_v,
    0,
    scale_x, -- scale_x: 1 is default, -1 for flip
    scale_y,
    self.center, -- anchor_x
    sprite_v_mid, -- anchor_y
    0,
    0,
    RGBTable}
end

-- called each frame while condition is valid
function Particle:preRepeatFX(sprite_center_h, sprite_v, h_shift, v_shift, facing, delay_time, sound_boolean, RGBTable)
  draw_count = draw_count + 1
  local delay = delay_time or 0
  local current_anim = math.floor((frame + delay) % self.total_time / self.time_per_frame)
  prebuffer[frame + delay] = prebuffer[frame + delay] or {}
  prebuffer[frame + delay][draw_count] = self:getDrawable(current_anim,
    sprite_center_h - self.center + (facing * h_shift),
    sprite_v + v_shift,
    facing, math.abs(facing), RGBTable)
  if sound_boolean then self:playSound(delay_time) end
end

-- called each frame while condition is valid
function Particle:postRepeatFX(sprite_center_h, sprite_v, h_shift, v_shift, facing, delay_time, sound_boolean, RGBTable)
  draw_count = draw_count + 1
  local delay = delay_time or 0
  local current_anim = math.floor((frame + delay) % self.total_time / self.time_per_frame)
  postbuffer[frame + delay] = postbuffer[frame + delay] or {}
  postbuffer[frame + delay][draw_count] = self:getDrawable(current_anim,
    sprite_center_h - self.center + (facing * h_shift),
    sprite_v + v_shift,
    facing, math.abs(facing), RGBTable)
  if sound_boolean then self:playSound(delay_time) end
end

-- called once, loads entire anim
function Particle:postLoadFX(sprite_center_h, sprite_v, h_shift, v_shift, facing, delay_time, sound_boolean, RGBTable)
  draw_count = draw_count + 1
  local delay = delay_time or 0
  for i = (frame + delay), (frame + delay + self.total_time) do
    local current_anim = math.floor((i - (frame + delay)) / self.time_per_frame)
    postbuffer[i] = postbuffer[i] or {}
    postbuffer[i][draw_count] = self:getDrawable(current_anim,
      sprite_center_h - self.center + (facing * h_shift),
      sprite_v + v_shift,
      facing, math.abs(facing), RGBTable)
  end
  if sound_boolean then self:playSound(delay_time) end
end

-- called once, loads entire anim
function Particle:preLoadFX(sprite_center_h, sprite_v, h_shift, v_shift, facing, delay_time, sound_boolean, RGBTable)
  draw_count = draw_count + 1
  local delay = delay_time or 0
  for i = (frame + delay), (frame + delay + self.total_time) do
    local current_anim = math.floor((i - (frame + delay)) / self.time_per_frame)
    prebuffer[i] = prebuffer[i] or {}
    prebuffer[i][draw_count] = self:getDrawable(current_anim,
      sprite_center_h - self.center + (facing * h_shift),
      sprite_v + v_shift,
      facing, math.abs(facing), RGBTable)
  end
  if sound_boolean then self:playSound(delay_time) end
end

function Particle:playSound(delay_time)
  writeSound(self.sound, delay_time)
end

--[[---------------------------------------------------------------------------
                            AFTERIMAGES SUB-CLASS
-----------------------------------------------------------------------------]]   
AfterImage = class('AfterImage', Particle)
function AfterImage:initialize(image, image_size, sprite_size, time_per_frame, sound)
  Particle.initialize(self, image, image_size, sprite_size, time_per_frame, sound)
end

function AfterImage:loadFX(sprite_center_h, sprite_v, h_shift, v_shift, facing)
  local shadow = {
    [8] = {255, 180, 0, 200},
    [16] = {255, 180, 0, 150}, 
    [24] = {255, 180, 0, 100}
  }
  for s_frame, color in pairs(shadow) do
    draw_count = draw_count + 1
    prebuffer[frame + s_frame] = prebuffer[frame + s_frame] or {}
    prebuffer[frame + s_frame][draw_count] = self:getDrawable(0,
      sprite_center_h - self.center + (facing * h_shift),
      sprite_v + v_shift,
      facing, math.abs(facing), color)
  end

end

---------------------------------- OVERLAYS -----------------------------------
 
FrogFactor = Particle:new(love.graphics.newImage('images/FrogFactor.png'), -- OK 2
  {1176, 130}, {168, 130}, 4)
SuperBarBase = Particle:new(love.graphics.newImage('images/SuperBarBase.png'), -- OK 2
  {196, 19}, {196, 19}, 1)
SuperMeter = Particle:new(love.graphics.newImage('images/SuperMeter.png'), -- OK 2
  {192, 120}, {192, 15}, 8)
------------------------------ COMMON PARTICLES -------------------------------
Mugshot = Particle:new(love.graphics.newImage('images/Mugshot.png'),
  {600, 140}, {600, 140}, 60, "Mugshot.ogg", true, true)
Dizzy = Particle:new(love.graphics.newImage('images/Dizzy.png'), -- OK 2
  {70, 50}, {70, 50}, 1, true)
OnFire = Particle:new(love.graphics.newImage('images/OnFire.png'), -- OK 2
  {800, 200}, {200, 200}, 3)
JumpDust = Particle:new(love.graphics.newImage('images/JumpDust.png'), -- OK 2
  {528, 60}, {132, 60}, 4, "dummy.ogg", true, true)
KickbackDust = Particle:new(love.graphics.newImage('images/KickbackDust.png'), -- OK 2
  {162, 42}, {54, 42}, 4)
WireSea = Particle:new(love.graphics.newImage('images/WireSea.png'), -- OK 2
  {1600, 220}, {200, 220}, 2, "WireSea.ogg", true, true)
Explosion1 = Particle:new(love.graphics.newImage('images/Explosion1.png'), 
  {800, 80}, {80, 80}, 3, "Explosion.ogg", true, true)
Explosion2 = Particle:new(love.graphics.newImage('images/Explosion2.png'), -- OK 2
  {880, 80}, {80, 80}, 3, "Explosion.ogg", true, true)
Explosion3 = Particle:new(love.graphics.newImage('images/Explosion3.png'), -- OK 2
  {880, 80}, {80, 80}, 3, "Explosion.ogg", true, true)


----------------------------------- KONRAD ------------------------------------
HyperKickFlames = Particle:new(love.graphics.newImage('images/Konrad/HyperKickFlames.png'), -- OK 2
  {800, 200}, {200, 200}, 2, "Konrad/KonradHyperKick.ogg")
DoubleJumpDust = Particle:new(love.graphics.newImage('images/Konrad/DoubleJumpDust.png'), -- OK 2
  {162, 43}, {54, 43}, 4, "Konrad/KonradDoubleJump.ogg")

-------------------------------- SUN BADFROG ----------------------------------
SunAura = Particle:new(love.graphics.newImage('images/Sun/Aura.png'), -- OK 2
  {800, 250}, {200, 250}, 6)
Hotflame = Particle:new(love.graphics.newImage('images/Sun/HotflameFX.png'), -- OK 2
  {120, 195}, {60, 195}, 4, "Sun/Hotflame.ogg")
Hotterflame = Particle:new(love.graphics.newImage('images/Sun/HotterflameFX.png'), -- OK 2
  {300, 252}, {150, 252}, 4, "Sun/Hotterflame.ogg")