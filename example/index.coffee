"use strict"

{Phaser} = this

{atan2, cos, max, min, PI, sin} = Math

{Back, Circular, Cubic, Default, Exponential, Linear, Quadratic, Sinusoidal} = Phaser.Easing

{linear} = Phaser.Math

{SECOND} = Phaser.Timer

DEFAULT_STATE = "balls"
FONT = "16px monospace"
FOREVER = 0
STYLE = backgroundColor: "black", fill: "white", font: FONT
TURN = 2 * PI

captionUpdateInterval = 100
fpsProblems = 0
lastFpsProblemInterval = 0
lastFpsProblemTime = 0

Phaser.BatchEmitter::debug = on
Phaser.BatchEmitter::log   = on

class SpiralingWatcher extends Phaser.Plugin

  init: ->
    @spiraling = new Phaser.Signal
    return

  update: ->
    if @game.time.suggestedFps < 30
      @spiraling.dispatch()
    return

states =

  boot:

    private: yes

    init: ->
      @game.forceSingleUpdate = off
      @game.fpsProblemNotifier.add @onFpsProblem.bind this
      @game.timing = @game.plugins.add Phaser.Plugin.AdvancedTiming,
        mode: "graph"
        visible: no
      @game.timing.activeDisplay.alignIn @world.bounds, Phaser.TOP_RIGHT
      @game.watcher = @game.plugins.add SpiralingWatcher
      @game.watcher.spiraling.add @onSpiraling.bind this

      lastFpsProblemTime = @game.time.time
      return

    preload: ->
      @load.path = 'example/assets/'

      for key, url of {
        bubble:     'bubble256.png'
        circle:     'blue-circle.png'
        colormap:   'colormap.png'
        fireball:   'fireball.png'
        fog:        'particle1.png'
        hsl:        'hsl.png'
        rabbit:     'wabbit.png'
        rain:       'rain.png'
        raster:     'yellow-pink-raster.png'
        star:       'star.png'
        star2:      'star2.png'
      }
        @load.image key, url

      for key, data of {
        balls:      ['balls.png',                     17, 17]
        food:       ['fruitnveg32wh37.png',           32, 32, 36]
        gameboy:    ['gameboy_seize_color_40x60.png', 40, 60]
        snowflakes: ['snowflakes_large.png',          64, 64]
      }
        @load.spritesheet key, data[0], data[1], data[2]

      return

    create: ->
      @createCaption()
      @createMenu()
      @bindControls()

      @state.onStateChange.add @onStateChange.bind this
      @state.start DEFAULT_STATE

      return

    bindControls: ->
      id = document.getElementById.bind document
      @$restart = id "restart"
      id "debug"
        .addEventListener "change", @onDebugChanged.bind this
      id "fullscreen"
        .addEventListener "click", @onFullscreenClicked.bind this
      id "menu"
        .addEventListener "change", @onMenuChanged.bind this
      id "performance"
        .addEventListener "change", @onPerformanceChanged.bind this
      @$restart
        .addEventListener "click", @restart.bind this
      return

    captionUpdate: ->
      if @alive
        {emitter} = @game.state.getCurrentState()
        if emitter and emitter.debug
          @text = ("#{key}: #{val}" for key, val of emitter.debugInfo).join "\t"
        @alive = no
      return

    createCaption: ->
      caption = @game.caption = @stage.addChild @game.make.text 0, 0, "Hello", STYLE
        .alignIn @world.bounds, Phaser.BOTTOM_LEFT
      caption.exists = no
      caption.update = @captionUpdate.bind caption
      return

    createMenu: ->
      el = document.createElement.bind document

      names = []
      names.push stateName for stateName, state of states when not state.private

      $menu = document.getElementById "menu"
      $menu.appendChild el "option" # blank

      for name in names
        $opt = el "option"
        $opt.textContent = name
        $menu.appendChild $opt

      @$menu = $menu

      return

    onDebugChanged: (event) ->
      @game.caption.exists = event.target.checked
      return

    onFpsProblem: ->
      {time} = @game.time
      fpsProblems += 1
      lastFpsProblemInterval = time - lastFpsProblemTime
      lastFpsProblemTime = time
      console.warn "fpsProblem (#{fpsProblems}) +#{lastFpsProblemInterval}ms #{@game._spiraling}"
      return

    onFullscreenClicked: ->
      @scale.startFullScreen()
      return

    onMenuChanged: (event) ->
      console.log event.target.value
      @state.start event.target.value
      return

    onPerformanceChanged: ->
      @game.timing.visible = not @game.timing.visible
      return

    onSpiraling: ->
      @game.state.start "fpsProblem"
      return

    onStateChange: (current, prev) ->
      @resetFpsProblemCount()
      @game.lockRender = off
      @refreshMenu current
      @$restart.disabled = @state.getCurrentState().private
      @game.time.events.loop captionUpdateInterval, @pokeCaption, this
      console.log "start", current, prev
      console.log "lockRender", @game.lockRender
      return

    pokeCaption: ->
      @game.caption.alive = yes
      return

    refreshMenu: (state) ->
      @$menu.value = state
      return

    resetFpsProblemCount: ->
      fpsProblems = 0
      console.log "resetFpsProblemCount", fpsProblems
      return

    restart: ->
      @state.restart()
      return

  balls:

    create: ->
      {height, width} = @world

      @emitter = @add.batchEmitter @world.bounds.left, @world.bounds.bottom, maxParticles = 10000
        .setAngularDrag TURN / 60
        .setDrag width / 96, 0
        .setGravity height / 8
        .setRotation -2 * TURN, 2 * TURN
        .setXSpeed width / -4, width / 4
        .setYSpeed height / -2, 0
        .makeParticles 'balls', [0, 1, 2, 3, 4], ~~(maxParticles / 5)
        .flow 5 * SECOND, 20, maxParticles / 250

      @add.tween(@emitter).to
        emitX: @world.bounds.right
        2.5 * SECOND, Sinusoidal.InOut, yes, 0, -1, yes

      return

    update: ->
      {height, width} = @world
      for child in @emitter.children when child.visible
        {x, y} = child.position
        if x < 0 or x > width  then child.vx *= -1
        if          y > height then child.vy *= -1
      return

  bubbles:

    create: ->
      lifespan = 5 * SECOND
      @emitter = @add.batchEmitter 0, 0, maxParticles = 500
        # .setAlphaTween 1, 0, 5000, Quadratic.Out
        .setAlpha 0.1, 0.3
        .setArea @world.bounds.left, @world.bounds.bottom, @world.width, 1
        .setGravity -10
        .setRotation TURN / -5, TURN / 5
        .setScaleTween 0, 0.5, 0, 0.5, lifespan, Back.Out
        .setXSpeed -50, 50
        .setYSpeed -50, -150
        .makeParticles 'bubble'
        .flow lifespan, 10, 1
      return

  # colors:
  #
  #   create: ->
  #     lifespan = 10 * SECOND
  #     @emitter = @add.batchEmitter @world.bounds.left, @world.bounds.top, maxParticles = 10
  #       .setAlphaTween 0, 0.25, lifespan, Linear.None, yes
  #       .setAnchor 0, 0
  #       .setScaleTween 0, 4, 4, 4, lifespan, Linear.None
  #       .setXSpeed @world.width / -10, @world.width / 10
  #       .makeParticles 'colormap'
  #       .flow 5 * SECOND, 1 * SECOND, 1
  #     return

  colors:

    create: ->
      lifespan = 10 * SECOND

      @emitter = @add.batchEmitter @world.bounds.left, @world.bounds.top, maxParticles = 10
        .setAlphaTween 0, 0.25, lifespan, Sinusoidal.InOut, yes
        .setAnchor 0.5, 0
        .setArea 0, @world.bounds.bottom, @world.width, 1
        # .setScale -4, 4, -4, -4
        .setScaleTween 4, -4, -4, -4, lifespan, Sinusoidal.InOut, yes
        .setSize @world.width, 1
        .setXSpeed @world.width / -10, @world.width / 10
        .makeParticles 'colormap'
        .flowAuto lifespan, null, 1

      return

  explode:

    create: ->
      {bounds, height, width} = @world

      @emitter = @add.batchEmitter 0, 0, maxParticles = 10000
        .setArea bounds.left, bounds.bottom, width, 1
        .setGravity height / 4
        .setRotation -TURN, TURN
        .setSpeed width / -15, width / 15, height * -1.5, height * -0.5
        .makeParticles 'food', keys = Phaser.ArrayUtils.numberArray(0, 24), maxParticles / keys.length
        .explode 15 * SECOND

      return

    update: ->
      {height, width} = @world

      for child in @emitter.children when child.visible and (
          child.position.x < 0     or
          child.position.x > width or
          child.vy > 0 and child.position.y > height)
        child.kill()

      return

  field:

    create: ->
      bounds = @world.bounds.clone().scale(0.5).offset @game.width / 4, @game.height / 4
      lifespan = 10 * SECOND
      {rnd} = @game

      @emitter = @add.batchEmitter bounds.left, bounds.top, maxParticles = 100
        .setAlphaTween 0, 0.1, lifespan, Cubic.InOut, yes
        .setPosition bounds.left, bounds.top
        .setScaleTween 0, 1, 0, 1, lifespan, Cubic.InOut, yes
        .makeParticles 'circle'
        .flowAuto lifespan, 100, null

      @add.tween @emitter
        .to
          emitX: bounds.right
          lifespan * rnd.between(1, 5), Sinusoidal.InOut, yes, 0, -1, yes

      @add.tween @emitter
        .to
          emitY: bounds.bottom
          lifespan / rnd.between(1, 5), Sinusoidal.InOut, yes, 0, -1, yes

      @add.tween @emitter
        .from
          lifespan: lifespan / rnd.between(1, 5)
          lifespan, Sinusoidal.InOut, yes, 0, -1, yes

      return

  fireball:

    create: ->
      lifespan = 5 * SECOND
      frequency = 100
      @emitter = @add.batchEmitter @world.centerX, @world.centerY, maxParticles = 100
        .setGravity -50
        .setAlphaTween 0.1, 0, lifespan, Cubic.Out
        .setDrag 5, 5
        .setScaleTween 0, 8, 0, 8, lifespan, Cubic.Out
        .setSpeed -20, 20, -20, 20
        .makeParticles 'fireball'
        .flow lifespan, 100, maxParticles * frequency / lifespan
      return

    update: ->
      {activePointer} = @input
      if activePointer.isDown
        @emitter.emitX = linear @emitter.emitX, activePointer.x, 1/60
        @emitter.emitY = linear @emitter.emitY, activePointer.y, 1/60
        # @emitter.emitX = activePointer.x
        # @emitter.emitY = activePointer.y
      return

  fireworks:

    create: ->
      lifespan = 4 * SECOND
      frequency = 2 * SECOND

      @bounds = @world.bounds.clone()

      @emitter = @add.batchEmitter @world.centerX, @world.centerY, maxParticles = 1000
      @emitter.resetChild = @emitterResetChild.bind @emitter
      @emitter
        # .setArea 0, 0, @world.width, @world.height
        .setGravity 500
        .setAlphaTween 1, 0, lifespan, Cubic.In
        .setScaleTween 0.5, 0, 0.5, 0, lifespan, Cubic.Out
        .setSpeed -1000, 1000
        .makeParticles 'star'
        .flow lifespan, frequency, maxParticles * frequency / lifespan

      @time.events.loop frequency / 2, @moveEmitter, this

      return

    update: ->
      drag = 59 / 60
      for child in @emitter.children when child.visible
        child.vx *= drag
        child.vy *= drag
      return

    emitterResetChild: (child) ->
      {rnd} = @game
      child.reset @emitX, @emitY
      child.lifespan = @lifespan
      angle = TURN * Math.random()
      speed = rnd.realInRange @minParticleSpeed.x, @maxParticleSpeed.x
      child.vx = speed * cos angle
      child.vy = speed * sin angle
      child

    moveEmitter: ->
      @emitter.emitX = @bounds.randomX
      @emitter.emitY = @bounds.randomY
      return

  fpsProblem:

    private: yes

    create: ->
      @add.text 0, 0, "Stopped because of low FPS :(", STYLE
        .alignIn @world.bounds, Phaser.CENTER
      return

    render: ->
      @game.lockRender = on
      console.log "lockRender", @game.lockRender
      return

  fog:

    create: ->
      {height, width} = @world
      lifespan = 10 * SECOND
      @emitter = @add.batchEmitter @world.bounds.left, @world.bounds.top, maxParticles = 1000
        .setAlphaTween 0, 0.1, lifespan, Quadratic.InOut, yes
        .setScale 5, 15
        .setSize @world.width, @world.height
        .setXSpeed -50, 50
        .setYSpeed -25, 25
        .makeParticles 'fog'
        .flow 10 * SECOND, 100, maxParticles / 100
      return

  kaleidoscope:

    create: ->
      lifespan = 5 * SECOND
      @emitter = @add.batchEmitter @world.bounds.left, @world.bounds.top, maxParticles = 1000
        .copyAreaFrom @world.bounds
        .setAlphaTween 0, 0.25, lifespan, Sinusoidal.InOut, yes
        .setGravity 20
        .setScale 1, 3
        .setSpeed 100
        .setRotation TURN / 5, TURN / 5
        .makeParticles 'gameboy', [0, 1, 2, 3, 4], maxParticles / 5
        .flowAuto 10 * SECOND, 100, null

      return

  profile:

    create: ->
      {game} = this
      {height, width} = @world

      console.profile "create: '#{@key}'"

      @emitter = @add.batchEmitter @world.bounds.left, @world.bounds.bottom, maxParticles = 10000
        .setAngularDrag TURN / 60
        .setDrag 10, 0
        .setGravity height / 8
        .setRotation -TURN, TURN
        .setXSpeed width / -4, width / 4
        .setYSpeed height / -2, 0
        .makeParticles 'balls', [0, 1, 2, 3, 4], ~~(maxParticles / 5)
        .flow 5 * SECOND, 20, maxParticles / 250

      console.profileEnd()

      n = 1000

      game.enableStep()
      console.profile "emitter.update() x#{n}"

      while (n--)
        game.step()
        @emitter.update()

      console.profileEnd()
      game.disableStep()

      console.profile "update: '#{@key}'"
      @time.events.add 5 * SECOND, console.profileEnd, console

      return

  pulsar:

    preload: ->
      bm = @game.make.bitmapData(2, 1)
        .rect(0, 0, 1, 1, "rgb(0,0,255)")
        .rect(1, 0, 1, 1, "rgb(0,255,255)")

      tx = bm.generateTexture "pulsarTexture"

      console.log "pulsarTexture", tx
      console.log "pulsarTexture.baseTexture.source", tx.baseTexture.source

      @cache.addSpriteSheet "pulsar", null, tx.baseTexture.source, 1, 1, 2, 0, 0

      pulsar = @cache.getImage "pulsar", yes
      unless pulsar.frameData
        console.timeStamp "Missing frameData"
        console.warn "Missing frameData", tx.baseTexture.source

      return

    create: ->
      # testImg = @add.image @world.centerX, @world.centerY, "pulsar"
      # testImg.scale.set 100
      maxParticles = 5000
      @emitter = new Phaser.BatchEmitter @game
        .configure @world.centerX, @world.centerY, maxParticles / 2
        .setAlpha 0.01, 0.02
        .setDrag 50, 30
        .setGravity 100
        .setRotation -TURN, TURN
        .setScale 1, 100
        .setXSpeed -500, 500
        .setYSpeed -500, 500
        .makeParticles "pulsar", [0, 1]
        .shuffle()
        .flow 1000, 100, maxParticles / 10
      return

  rain:

    create: ->
      {height, width} = @world

      @wind = new Phaser.Point width / 8, height / 16
      @add.tween(@wind).to
        x: width  / -8
        y: height / -16
        60000, Sinusoidal.InOut, yes, 0, -1, yes

      @emitter = @add.batchEmitter @world.bounds.left, @world.bounds.top, maxParticles = 5000
        .setAlpha 0.25, 0.75
        .setGravity height / 50
        .setScale 0.5, 1
        .setSize @world.width, @world.height
        .setXSpeed width / -16, width / 16
        .setYSpeed height * 0.5, height * 1.5
        .makeParticles 'rain'
        .flow 1000, 100, maxParticles / 10
      return

    update: ->
      {physicsElapsed} = @time
      {x, y} = @wind

      x *= physicsElapsed
      y *= physicsElapsed

      for child in @emitter.children when child.visible
        child.vx += x
        child.vy += y
        child.rotation = atan2 child.vx, child.vy
      return

  rabbits:

    create: ->
      {height, width} = @world

      @emitter = @add.batchEmitter @world.bounds.left, @world.centerY, maxParticles = 10000
        .setGravity 100
        .setSpeed -100, 100, -200, 0
        .makeParticles 'rabbit'
        .flow 5000, 20, 40

      @add.tween(@emitter).to
        emitX: @world.bounds.right
        5000, Sinusoidal.InOut, yes, 0, -1, yes

      return

  raster:

    create: ->
      lifespan = 10 * SECOND
      # img = @add.image 0, 0, 'raster'
      # img.scale.set 100, 1
      # return
      @emitter = @add.batchEmitter @world.bounds.left, @world.bounds.top, maxParticles = 10
        .setAlphaTween 0, 0.25, lifespan, Sinusoidal.InOut, yes
        .setAnchor 0, 0
        .setScale 100, 100, 1, 1
        .setYSpeed @world.height / -5, @world.height / 5
        .makeParticles 'raster'
        .flowAuto 5000, null, 1
      console.log @emitter.children[0]
      return

  snow:

    create: ->
      {height, left, top, width} = @world

      @wind = new Phaser.Point width / 8, height / 16
      @add.tween(@wind).to
        x: width  / -8
        y: height / -16
        10000, Sinusoidal.InOut, yes, 0, -1, yes

      @emitter = @add.batchEmitter @world.bounds.left, @world.bounds.top, maxParticles = 1000
        .setAlpha 0.25, 0.75
        .setRotation TURN / -2, TURN / 2
        .setScale 0.125, 0.5
        .setSize @world.width, 0
        .setXSpeed width / -25, width / 25
        .setYSpeed height * 0.075, height * 0.125
        .makeParticles 'snowflakes', [0, 1, 2, 3, 4], ~~(maxParticles / 5)
        .shuffle()
        .flowAuto 10 * SECOND, 250, null
      return

    update: ->
      {height, width} = @world
      {physicsElapsed} = @time
      {x, y} = @wind

      x *= physicsElapsed / 10
      y *= physicsElapsed / 10

      for child in @emitter.children when child.visible
        child.vx += x * child.scale.x
        # child.vy += y * child.scale.y
        if      child.x < 0      then child.x += width
        else if child.x > width  then child.x -= width
        if      child.y < 0      then child.y += height
        else if child.y > height then child.y -= height
      return

  starfield:

    create: ->
      {height, width} = @world
      maxParticles = 10000
      lifespan = 1000
      interval = 100
      @emitter = @add.batchEmitter @world.bounds.left, @world.bounds.top, maxParticles
        .setAlphaTween 0, 1
        .setPosition @world.centerX, @world.centerY
        .setSpeed width / -2, width / 2
        .makeParticles 'star2'
        .flow lifespan, interval, maxParticles / 10
      return

startGame = ->
  @GAME = game = new Phaser.Game
    enableDebug: no
    height:      window.innerHeight
    width:       window.innerWidth
    scaleMode:   Phaser.ScaleManager.NO_SCALE
  for key, state of states
    game.state.add key, state
  game.state.start "boot"
  game

startGame.call this
