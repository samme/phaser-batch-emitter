"use strict"

{Phaser, PIXI} = this

{max, min} = Math

{freeze} = Object

{Cache, Point, Rectangle} = Phaser

{getRandomItem, shuffle} = Phaser.ArrayUtils

{Core} = Phaser.Component

# BatchParticle

Phaser.BatchParticle = class BatchParticle extends PIXI.Sprite

  anchor:   freeze new Point 0.5, 0.5
  position: freeze new Point
  scale:    freeze new Point 1, 1
  type:     Phaser.IMAGE
  vr:       0
  vx:       0
  vy:       0

  constructor: (game, x = 0, y = 0, key = null, frame = null) ->
    PIXI.Sprite.call this, Cache.DEFAULT
    Core.init.call this, game, x, y, key, frame

Core.install.call BatchParticle.prototype, [
  'Animation' # required for @loadTexture -> @animations.loadFrameData
  'BringToTop'
  'Destroy'
  'LifeSpan'
  'LoadTexture'
  'Reset'
  'Smoothed'
]

# BatchEmitter

Phaser.BatchEmitter = class BatchEmitter extends Phaser.SpriteBatch

  @add = (game, x, y, maxParticles, parent = game.world, name, addToStage) ->
    @create game, x, y, maxParticles, parent, name, addToStage

  @create = (game, x, y, maxParticles, parent, name, addToStage) ->
    emitter = new this game
    emitter.configure x, y, maxParticles, parent, name, addToStage
    emitter

  _flowLimit: null
  _flowQuantity: null

  alphaData: null
  angularDrag: 0
  area: null
  autoAlpha: no
  autoScale: no
  debug: no
  emitX: 0
  emitY: 0
  frequency: 100
  gravity: 0
  lifespan: 2000
  log: no
  maxParticleAlpha: 1
  minParticleAlpha: 1
  maxParticles: 50
  maxParticleScale: null
  maxParticleSpeed: null
  maxRotation: 0
  minParticleScale: null
  minParticleSpeed: null
  minRotation: 0
  on: no
  particleAnchor: null
  particleBringToTop: no
  particleDrag: null
  particleSendToBack: no
  randomFrame: no
  scaleData: null

  Object.defineProperty @prototype, "length",
    get:       -> @children.length
    set: (val) -> @children.length = val

  constructor: -> # game, parent, name, addToStage
    super
    @classType = Phaser.BatchParticle
    @debugInfo = {}
    @maxParticleScale = new Point 1, 1
    @maxParticleSpeed = new Point
    @minParticleScale = new Point 1, 1
    @minParticleSpeed = new Point
    @particleAnchor   = new Point 0.5, 0.5

  _explode: (quantity) ->
    console.log "_explode", quantity if @log
    for child in @children when not child.exists
      @resetChild child
      quantity -= 1
      break unless quantity > 0
    return

  _renderCanvas: PIXI.SpriteBatch::_renderCanvas

  _renderWebGL: PIXI.SpriteBatch::_renderWebGL

  add: (child, silent = no, index) ->
    if child.parent is this
      return child
    unless index?
      child.z = @children.length
      @addChild child
    else
      @addChildAt child, index
      @updateZ()
    unless @cursor?
      @cursor = child
    child

  configure: (@emitX, @emitY, @maxParticles = 50) ->
    console.log "configure", @emitX, @emitY, @maxParticles if @log
    this

  copyAreaFrom: (rect) ->
    if @area
      @area.copyFrom rect
    else
      @area = rect.clone()
    this

  copyPositionFrom: (pos) ->
    @emitX = pos.x
    @emitY = pos.y
    this

  create: (x, y, key, frame, exists = yes, index) ->
    child = new @classType @game, x, y, key, frame
    child.exists = child.visible = child.alive = exists
    child.anchor = @particleAnchor
    @add child, no, index
    child

  createTimer: ->
    console.log "create timer" if @log
    @destroyTimer()
    @_timer = @game.time.create()
    @_timer.loop @frequency, @onLoop, this
    @_timer.start()
    console.log "start timer", @_timer.next if @log
    return

  destroy: ->
    super
    @destroyTimer()
    console.log "destroyed" if @log
    return

  destroyTimer: ->
    console.log "destroyTimer", @_timer if @log
    @_timer.destroy() if @_timer
    return

  explode: (lifespan = @lifespan, quantity = @maxParticles) ->
    console.log "explode", lifespan, quantity if @log
    @start yes, lifespan, 0, quantity, no
    @game.time.events.add lifespan, @kill, this
    this

  flow: (lifespan = @lifespan, frequency = @frequency, quantity = 1, limit = -1, immediate = yes) ->
    console.log "flow", lifespan, frequency, quantity, limit, immediate if @log
    @_flowLimit = limit
    if immediate
      @pendingEmit = yes
    @start no, lifespan, frequency, quantity
    this

  flowAuto: (lifespan, frequency, quantity) ->
    # maxParticles == quantity * lifespan / frequency
    console.log "flowAuto", lifespan, frequency, quantity if @log
    switch
      when not lifespan?
        lifespan = @maxParticles * frequency / quantity
        console.log "let lifespan =", lifespan if @log
      when not frequency?
        frequency = quantity * lifespan / @maxParticles
        console.log "let frequency =", frequency if @log
      when not quantity?
        quantity = @maxParticles * frequency / lifespan
        console.log "let quantity =", quantity if @log
      else
        throw new Error "You must pass exactly 1 null value for lifespan, frequency, or quantity"
    @flow lifespan, frequency, quantity
    this

  kill: ->
    console.log "kill" if @log
    @alive = @exists = @on = @visible = no
    @_timer.pause() if @_timer
    @updateDebugInfo()
    this

  makeParticles: (key, frame, quantity = @maxParticles) ->
    console.log "makeParticles", key, frame, quantity if @log
    @particleKey = key if key?
    @particleFrame = frame if frame?
    console.log "createMultiple", quantity, @particleKey, @particleFrame if @log
    @createMultiple quantity, @particleKey, @particleFrame
    console.log "length", @length if @log
    this

  onLoop: ->
    @pendingEmit = yes
    return

  postUpdate: ->
    if @fixedToCamera
      @x = @game.camera.view.x + @cameraOffset.x
      @y = @game.camera.view.y + @cameraOffset.y
    return

  preUpdate: ->
    if @pendingDestroy
      @destroy()
      return no
    unless @exists and @parent.exists
      @renderOrderID = -1
      return no
    yes

  resetChild: (child, x, y) ->
    {rnd} = @game
    {emitX, emitY} = this
    {position, scale} = child

    xMax = @maxParticleScale.x
    xMin = @minParticleScale.x
    yMax = @maxParticleScale.y
    yMin = @minParticleScale.y

    child.reset x, y

    child.lifespan = @lifespan if @lifespan

    if @maxParticleSpeed.x isnt 0 or @minParticleSpeed.x isnt 0
      child.vx =
        if @maxParticleSpeed.x is @minParticleSpeed.x
          @maxParticleSpeed.x
        else
          rnd.realInRange @minParticleSpeed.x, @maxParticleSpeed.x

    if @maxParticleSpeed.y isnt 0 or @minParticleSpeed.y isnt 0
      child.vy =
        if @maxParticleSpeed.y is @minParticleSpeed.y
          @maxParticleSpeed.y
        else
          rnd.realInRange @minParticleSpeed.y, @maxParticleSpeed.y

    if @area
      position.x = emitX + @area.randomX unless x?
      position.y = emitY + @area.randomY unless y?
    else
      position.x = emitX
      position.y = emitY

    if @maxParticleAlpha isnt 1 or @minParticleAlpha isnt 1
      child.alpha =
        if @autoAlpha or @maxParticleAlpha is @minParticleAlpha
          @maxParticleAlpha
        else
          rnd.realInRange @minParticleAlpha, @maxParticleAlpha

    if xMax isnt 1 or xMin isnt 1
      scale.x =
        if @autoScale or xMax is xMin
          xMax
        else
          rnd.realInRange xMin, xMax

    if yMax isnt 1 or yMin isnt 1
      scale.y =
        if @autoScale or yMax is yMin
          yMax
        else if xMin is yMin and xMax is yMax
          scale.x
        else
          rnd.realInRange yMin, yMax

    if @maxRotation isnt 0 or @minRotation isnt 0
      child.vr =
        if @maxRotation is @minRotation
          @maxRotation
        else
          rnd.realInRange @minRotation, @maxRotation

    # SLOW!
    if @particleBringToTop
      @bringToTop child
    else if @particleSendToBack
      @sendToBack child

    if @randomFrame
      child.frame = getRandomItem @particleFrame

    child

  remove: (child, destroy = no, silent = no) ->
    if @children.length is 0
      return no
    removed = @removeChild child
    @updateZ()
    if @cursor is child
      @next()
    if destroy and removed
      removed.destroy yes
    yes

  revive: ->
    console.log "revive" if @log
    @alive = @exists = @visible = yes
    @updateDebugInfo()
    this

  setAlpha: (@minParticleAlpha, @maxParticleAlpha = @minParticleAlpha) ->
    @autoAlpha = no
    this

  setAlphaTween: (start, end, duration = @lifespan, easing = Phaser.Easing.Default, yoyo) ->
    console.log "setAlphaTween", start, end, duration, easing.name, yoyo if @log
    @alphaData = @game.make.tween
        alpha: start
      .to
        alpha: end
        duration, easing, no, null, null, yoyo
      .generateData()
    @autoAlpha = yes
    this

  setAnchor: (x, y) ->
    @particleAnchor.set x, y
    this

  setAngularDrag: (@angularDrag) ->
    this

  setArea: (x, y, width, height) ->
    @area = new Rectangle unless @area
    @area.setTo x, y, width, height
    this

  setDrag: (x, y) ->
    @particleDrag = new Point unless @particleDrag
    @particleDrag.x = x
    @particleDrag.y = y
    this

  setGravity: (@gravity) ->
    this

  setPosition: (@emitX, @emitY) ->
    this

  setRotation: (@minRotation, @maxRotation) ->
    this

  setScale: (xMin, xMax = xMin, yMin = xMin, yMax = xMax) ->
    console.log "setScale", xMin, xMax, yMin, yMax if @log
    @minParticleScale.set xMin, yMin
    @maxParticleScale.set xMax, yMax
    console.log "minParticleScale", @minParticleScale.toString() if @log
    console.log "maxParticleScale", @maxParticleScale.toString() if @log
    @autoScale = no
    this

  setScaleTween: (xStart, xEnd, yStart = xStart, yEnd = xEnd, duration = @lifespan, easing = Phaser.Easing.Default, yoyo = no) ->
    console.log "setScaleTween", "x: #{xStart}, y: #{yStart}", "x: #{xEnd}, y: #{yEnd})", duration, easing.name if @log
    @scaleData = @game.make.tween
        x: xStart
        y: yStart
      .to
        x: xEnd
        y: yEnd
        duration, easing, no, null, null, yoyo
      .generateData()
    # console.log "scaleData", @scaleData if @log
    @autoScale = yes
    this

  setSize: (width, height) ->
    @area = new Rectangle unless @area
    @area.width = width
    @area.height = height
    console.log "setSize", @area.toString() if @log
    this

  setSpeed: (xMin, xMax = xMin, yMin = xMin, yMax = xMax) ->
    console.log "setSpeed", xMin, xMax, yMin, yMax if @log
    @setXSpeed xMin, xMax
    @setYSpeed yMin, yMax
    this

  setXSpeed: (xMin, xMax) ->
    console.log "setXSpeed", xMin, xMax if @log
    @minParticleSpeed.x = xMin
    @maxParticleSpeed.x = xMax
    this

  setYSpeed: (yMin, yMax) ->
    console.log "setYSpeed", yMin, yMax if @log
    @minParticleSpeed.y = yMin
    @maxParticleSpeed.y = yMax
    this

  shuffle: ->
    shuffle @children
    this

  start: (explode, lifespan, frequency, quantity, forceQuantity) ->
    console.log "start", explode, lifespan, frequency, quantity, forceQuantity if @log
    @lifespan = lifespan if lifespan?
    @frequency = frequency if frequency?
    if explode
      @destroyTimer()
      @_flowLimit = -1
      @_flowQuantity = -1
      @on = no
      @_explode quantity, @emitX, @emitY
    else
      @createTimer()
      @_flowQuantity = quantity
      @on = yes
    return

  update: ->
    return unless @exists

    if @_timer
      if @on then @_timer.resume() if @_timer.paused
      else        @_timer.pause()  if @_timer.running

    {stage} = @game
    {physicsElapsed, physicsElapsedMS} = @game.time
    {_flowQuantity, alphaData, angularDrag, autoAlpha, autoScale, children, debug, debugInfo, gravity, lifespan, particleDrag, pendingEmit, scaleData} = this

    alphaLength = alphaData?.length
    isOn = @on
    hasFlowLimit = @_flowLimit isnt -1
    scaleLength = scaleData?.length

    if angularDrag
      angularDragDelta = angularDrag * physicsElapsed

    if gravity
      gravityDelta = gravity * physicsElapsed

    if particleDrag
      dragXDelta = particleDrag.x * physicsElapsed
      dragYDelta = particleDrag.y * physicsElapsed

    if debug
      alive = 0
      dead = 0
      revived = 0
      killed = 0

    i = 0

    while child = children[i++]

      if child.lifespan > 0
        child.lifespan -= physicsElapsedMS
        if child.lifespan <= 0
          child._exists = child.visible = no
          child.renderOrderID = -1
          killed += 1 if debug

      child.renderOrderID =
        if child._exists
          stage.currentRenderOrderID++
        else
          child.renderOrderID = -1

      if pendingEmit and isOn and not child._exists
        @resetChild child
        revived += 1 if debug
        _flowQuantity -= 1
        if _flowQuantity is 0
          pendingEmit = no
        if hasFlowLimit
          @_flowLimit -= 1
          if @_flowLimit is 0
            @on = no
            pendingEmit = no
        @pendingEmit = pendingEmit

      if child._exists

        {position} = child

        child.visible = yes
        alive += 1 if debug
        lifetime = child.lifespan / lifespan
        antiLifetime = 1 - lifetime

        if angularDrag
          if child.vr > 0
            child.vr = max 0, child.vr - angularDragDelta
          else if child.vr < 0
            child.vr = min 0, child.vr + angularDragDelta

        if autoAlpha
          child.alpha = (alphaData[ ~~(alphaLength * antiLifetime) - 1 ] or alphaData[0]).alpha

        if autoScale
          scale = scaleData[ ~~(scaleLength * antiLifetime) - 1 ] or scaleData[0]
          child.scale.x = scale.x
          child.scale.y = scale.y

        if gravity
          child.vy += gravityDelta

        if particleDrag
          if child.vx > 0
            child.vx = max 0, child.vx - dragXDelta
          else if child.vx < 0
            child.vx = min 0, child.vx + dragXDelta
          if child.vy > 0
            child.vy = max 0, child.vy - dragYDelta
          else if child.vy < 0
            child.vy = min 0, child.vy - dragYDelta

        position.x     += child.vx * physicsElapsed
        position.y     += child.vy * physicsElapsed
        child.rotation += child.vr * physicsElapsed

      else

        dead += 1 if debug

    if @debug
      debugInfo.alive        = alive
      debugInfo.dead         = dead
      debugInfo.killed       = killed
      debugInfo.revived      = revived
      debugInfo.total        = @length
      debugInfo.flowLimit    = @_flowLimit
      debugInfo.flowQuantity = _flowQuantity
      debugInfo.next         = @_timer?.duration
      debugInfo.on           = isOn

    return

  updateDebugInfo: ->
    if @debug
      @debugInfo.alive = @alive
      @debugInfo.on = @on
      @debugInfo.exists = @exists
      @debugInfo.visible = @visible
    return

  updateTransform: PIXI.SpriteBatch::updateTransform

Phaser.GameObjectCreator::batchEmitter = (x, y, maxParticles, parent, name, addToStage) ->
  BatchEmitter.create @game, x, y, maxParticles, parent, name, addToStage

Phaser.GameObjectFactory::batchEmitter = (x, y, maxParticles, parent, name, addToStage) ->
  BatchEmitter.add @game, x, y, maxParticles, parent, name, addToStage
