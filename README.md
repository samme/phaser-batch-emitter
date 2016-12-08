Phaser Batch Emitter ✨
====================

Fast, no-physics particle emitter based on [Phaser.SpriteBatch](http://phaser.io/docs/2.6.2/Phaser.SpriteBatch.html).

```javascript
game.add.batchEmitter(x, y, maxParticles)
    // configure …
    .makeParticles(key, frame, quantity)
    .explode()
    // or
    .flow()
```

It works very similarly to [Phaser.Particles.Arcade.Emitter](http://phaser.io/docs/2.6.2/Phaser.Particles.Arcade.Emitter.html). See the [examples](https://samme.github.io/phaser-batch-emitter/) and [source](https://github.com/samme/phaser-batch-emitter/blob/master/index.coffee) for details. You can set

```javascript
emitter.debug = true;
emitter.log = true;
```

to see better what your emitter is doing.

Differences to Phaser.Particles.Arcade.Emitter
----------------------------------------------

  - `rotation` is in radians, not degrees
  - `makeParticles` works like [Phaser.Group#createMultiple](http://phaser.io/docs/2.6.2/Phaser.Group.html#createMultiple) for multiple frames

Not yet implemented
-------------------

  - [ ] autoAlpha duration
  - [ ] autoScale duration

Best performance
----------------

    angularDrag: 0
    maxRotation: 0
    minRotation: 0
    particleBringToTop: false
    particleDrag: null
    particleSendToBack: false
