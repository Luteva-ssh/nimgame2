import
  sdl2_nim/sdl,
  nimgame2/nimgame,
  nimgame2/settings,
  mainscene

game = newGame()
if game.init(w = 640, h = 480, title = "Nimgame 2: Demo 5 (Collisions)",
             scaleQuality = 0):
  showInfo = true
  colliderOutline = true
  discard sdl.showCursor(0)
  game.scene = newMainScene()
  game.run()

