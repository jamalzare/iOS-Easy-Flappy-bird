//
//  ViewController.swift
//  GameScene
//
//  Created by Jamal on 5/10/17.


//for window of gavem


import SpriteKit
import GameplayKit

enum Layer: CGFloat {
  case Background
  case Obstacle
  case Foreground
  case Player
  case UI
  case Flash
}



struct PhysicsCategory {
  static let None: UInt32 =       0     // 0
  static let Player: UInt32 =     0b1   // 1
  static let Obstacle: UInt32 =   0b10  // 2
  static let Ground: UInt32 =     0b100 // 4
}

protocol GameSceneDelegate {
  func screenshot() -> UIImage
  func shareString(string: String, url: NSURL, image: UIImage)
}

protocol TVControlsScene {
    func setupTVControls()
}

class GameScene: SKScene, SKPhysicsContactDelegate {
  
  var gameSceneDelegate: GameSceneDelegate
  let appStoreID = 820464950
  
  let worldNode = SKNode()
  
  var playableStart: CGFloat = 0
  var playableHeight: CGFloat = 0
  
  var numberOfForegrounds = 2
  let groundSpeed: CGFloat = 150
  
  var deltaTime: NSTimeInterval = 0
  var lastUpdateTimeInterval: NSTimeInterval = 0
  
  let player = Player(imageName: "Bird0")
  
  let bottomObstacleMinFraction: CGFloat = 0.1
  let bottomObstacleMaxFraction: CGFloat = 0.6
  
  let gapMultiplier: CGFloat = 3.5
  
  let firstSpawnDelay: NSTimeInterval = 1.75
  let everySpawnDelay: NSTimeInterval = 1.5
  
  lazy var gameState: GKStateMachine = GKStateMachine(states: [
    MainMenuState(scene: self),
    TutorialState(scene: self),
    PlayingState(scene: self),
    FallingState(scene: self),
    GameOverState(scene: self)
    ])
  
  var scoreLabel: SKLabelNode!
  var score = 0
  
  var fontName = "AmericanTypewriter-Bold"
  var margin: CGFloat = 20.0
  
  let popAction = SKAction.playSoundFileNamed("pop.wav", waitForCompletion: false)
  let coinAction = SKAction.playSoundFileNamed("coin.wav", waitForCompletion: false)
  
  var initialState: AnyClass
  
  init(size: CGSize, stateClass: AnyClass, delegate: GameSceneDelegate) {
    gameSceneDelegate = delegate
    initialState = stateClass
    super.init(size: size)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func didMoveToView(view: SKView) {
    
    physicsWorld.gravity = CGVector(dx: 0, dy: 0)
    physicsWorld.contactDelegate = self
    
    addChild(worldNode)
    // setupBackground()
    // setupForeground()
    // setupPlayer()
    // setupScoreLabel()
    
    // startSpawning()
    // gameState.enterState(PlayingState)
    gameState.enterState(initialState)
    
    let scene = (self as SKScene)
    if let scene = scene as? TVControlsScene {
        scene.setupTVControls()
    }
  }
  
  // MARK: Setup methods
  
  func setupBackground() {
    
    let background = SKSpriteNode(imageNamed: "Background")
    let numberOfSprites = Int(size.width / background.size.width) + 1
    
    for i in 0..<numberOfSprites {
      let background = SKSpriteNode(imageNamed: "Background")
      background.anchorPoint = CGPoint(x: 0.0, y: 1.0)
      background.position = CGPoint(x: CGFloat(i) * background.size.width + 1, y: size.height)
        background.zPosition = Layer.Background.rawValue
        background.name = "background"
      
        worldNode.addChild(background)
    }
    
    playableStart = size.height - background.size.height
    playableHeight = background.size.height
    
    let lowerLeft = CGPoint(x: 0, y: playableStart)
    let lowerRight = CGPoint(x: size.width, y: playableStart)
    
    // Add physics
    physicsBody = SKPhysicsBody(edgeFromPoint: lowerLeft, toPoint: lowerRight)
    physicsBody?.categoryBitMask = PhysicsCategory.Ground
    physicsBody?.collisionBitMask = 0
    physicsBody?.contactTestBitMask = PhysicsCategory.Player
  }
  
  func setupForeground() {
    let foreground = SKSpriteNode(imageNamed: "Ground")
    let numberOfSprites = Int(size.width / foreground.size.width) + 2
    
    numberOfForegrounds = numberOfSprites
    
    for i in 0..<numberOfSprites {
      let foreground = SKSpriteNode(imageNamed: "Ground")
      foreground.anchorPoint = CGPoint(x: 0.0, y: 1.0)
      foreground.position = CGPoint(x: CGFloat(i) * foreground.size.width, y: playableStart)
        foreground.zPosition = Layer.Foreground.rawValue
        foreground.name = "foreground"
      
        worldNode.addChild(foreground)
    }
  }
  
  func setupPlayer() {
    let playerNode = player.spriteComponent.node
    playerNode.position = CGPoint(x: size.width * 0.2, y: playableHeight * 0.4 + playableStart)
    playerNode.zPosition = Layer.Player.rawValue
    
    worldNode.addChild(playerNode)
    
    player.movementComponent.playableStart = playableStart
    
    player.animationComponent.startWobble()
  }
  
  func setupScoreLabel() {
    scoreLabel = SKLabelNode(fontNamed: fontName)
    scoreLabel.fontColor = SKColor(red: 101.0/255.0, green: 71.0/255.0, blue: 73.0/255.0, alpha: 1.0)
    scoreLabel.position = CGPoint(x: size.width/2, y: size.height - margin)
    scoreLabel.verticalAlignmentMode = .Top
    scoreLabel.zPosition = Layer.UI.rawValue
    
    scoreLabel.text = "\(score)"
    
    worldNode.addChild(scoreLabel)
  }
  
  // MARK: Obstacle methods
  
  func startSpawning() {
    let firstDelay = SKAction.waitForDuration(firstSpawnDelay)
    let spawn = SKAction.runBlock(spawnObstacle)
    let everyDelay = SKAction.waitForDuration(everySpawnDelay)
    
    let spawnSequence = SKAction.sequence([spawn, everyDelay])
    let foreverSpawn = SKAction.repeatActionForever(spawnSequence)
    let overallSequence = SKAction.sequence([firstDelay, foreverSpawn])
    
    // runAction(overallSequence)
    runAction(overallSequence, withKey: "spawn")
  }
  
  func stopSpawning() {
    removeActionForKey("spawn")
    worldNode.enumerateChildNodesWithName("obstacle", usingBlock: {node, stop in
      node.removeAllActions()
    })
  }
  
  func createObstacle() -> SKSpriteNode {
    let obstacle = Obstacle(imageName: "Cactus")
    let obstacleNode = obstacle.spriteComponent.node
    obstacleNode.zPosition = Layer.Obstacle.rawValue
    
    obstacleNode.name = "obstacle"
    obstacleNode.userData = NSMutableDictionary()
    
    return obstacle.spriteComponent.node
  }
  
  func spawnObstacle() {
    
    // Bottom obstacle
    let bottomObstacle = createObstacle()
    let startX = size.width + bottomObstacle.size.width/2
    
    let bottomObstacleMin = (playableStart - bottomObstacle.size.height/2) + playableHeight * bottomObstacleMinFraction
    let bottomObstacleMax = (playableStart - bottomObstacle.size.height/2) + playableHeight * bottomObstacleMaxFraction
    
    // let randomValue = CGFloat.random(min: bottomObstacleMin, max: bottomObstacleMax)
    
    // Using GameplayKit's randomization
    let randomSource = GKARC4RandomSource()
    let randomDistribution = GKRandomDistribution(randomSource: randomSource, lowestValue: Int(round(bottomObstacleMin)), highestValue: Int(round(bottomObstacleMax)))
    let randomValue = randomDistribution.nextInt()
    
    bottomObstacle.position = CGPointMake(startX, CGFloat(randomValue))
    worldNode.addChild(bottomObstacle)
    
    // Top obstacle
    let topObstacle = createObstacle()
    topObstacle.zRotation = CGFloat(180).degreesToRadians()
    topObstacle.position = CGPoint(x: startX, y: bottomObstacle.position.y + bottomObstacle.size.height/2 + topObstacle.size.height/2 + player.spriteComponent.node.size.height * gapMultiplier)
    worldNode.addChild(topObstacle)
    
    let moveX = size.width + topObstacle.size.width
    let moveDuration = moveX / groundSpeed
    
    let sequence = SKAction.sequence([
      SKAction.moveByX(-moveX, y: 0, duration: NSTimeInterval(moveDuration)),
      SKAction.removeFromParent()
      ])
    
    topObstacle.runAction(sequence)
    bottomObstacle.runAction(sequence)
  }
  
  // MARK: Game Play
  
  override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
    
    #if os(iOS)
    if let touch = touches.first{
      let touchLocation = touch.locationInNode(self)
      
      switch gameState.currentState {
      case is MainMenuState:
        if touchLocation.y < size.height * 0.15 {
          learn()
        } else if touchLocation.x < size.width * 0.6 {
          restartGame(TutorialState)
        } else {
          rateApp()
        }
      case is TutorialState:
        gameState.enterState(PlayingState)
      case is PlayingState:
        player.movementComponent.applyImpulse(lastUpdateTimeInterval)
      case is GameOverState:
        if touchLocation.x < size.width * 0.6 {
          restartGame(TutorialState)
        } else {
          shareScore()
        }
      default:
        break
      }
    }
    #endif
  }
  
  func restartGame(stateClass: AnyClass) {
    runAction(popAction)
    
    let newScene = GameScene(size: size, stateClass: stateClass, delegate: gameSceneDelegate)
    let transition = SKTransition.fadeWithColor(SKColor.blackColor(), duration: 0.02)
    view?.presentScene(newScene, transition: transition)
  }
  
  // MARK: Physics
  
  func didBeginContact(contact: SKPhysicsContact) {
    let other = contact.bodyA.categoryBitMask == PhysicsCategory.Player ? contact.bodyB : contact.bodyA
    
    if other.categoryBitMask == PhysicsCategory.Ground {
      // print("hit ground")
      gameState.enterState(GameOverState)
    }
    if other.categoryBitMask == PhysicsCategory.Obstacle {
      // print("hit obstacle")
      gameState.enterState(FallingState)
    }
  }
  
  // MARK: Updates
  
  override func update(currentTime: CFTimeInterval) {
    if lastUpdateTimeInterval == 0 {
      lastUpdateTimeInterval = currentTime
    }
    
    deltaTime = currentTime - lastUpdateTimeInterval
    lastUpdateTimeInterval = currentTime
    
    // Begin updates
    // updateForeground()
    gameState.updateWithDeltaTime(deltaTime)
    
    // Per-Entity updates
    player.updateWithDeltaTime(deltaTime)
  }
  
  func updateScore() {
    worldNode.enumerateChildNodesWithName("obstacle", usingBlock: {node, stop in
      if let obstacle = node as? SKSpriteNode {
        if let passed = obstacle.userData?["Passed"] as? NSNumber {
          if passed.boolValue {
            return
          }
        }
        if self.player.spriteComponent.node.position.x > obstacle.position.x + obstacle.size.width/2 {
          self.score++
          self.scoreLabel.text = "\(self.score/2)"
          
          obstacle.userData?["Passed"] = NSNumber(bool: true)
          self.runAction(self.coinAction)
        }
      }
    })
  }
  
  func updateForeground() {
    worldNode.enumerateChildNodesWithName("foreground", usingBlock: { node, stop in
      if let foreground = node as? SKSpriteNode {
        let moveAmount = CGPoint(x: -self.groundSpeed * CGFloat(self.deltaTime), y: 0)
        foreground.position += moveAmount
        
        if foreground.position.x < -foreground.size.width {
          foreground.position += CGPoint(x: foreground.size.width * CGFloat(self.numberOfForegrounds), y: 0)
        }
      }
    })
  }
  
  // MARK: Extras
  func shareScore() {
    let urlString = "https://itunes.apple.com/app/flappy-felipe/id\(appStoreID)?mt=8"
    let url = NSURL(string: urlString)
    
    let screenshot = gameSceneDelegate.screenshot()
    let initialTextString = "OMG! I scored \(score/2) points in Flappy Felipe!"
    gameSceneDelegate.shareString(initialTextString, url: url!, image: screenshot)
  }
  
  func rateApp() {
    let urlString = "https://itunes.apple.com/app/flappy-felipe/id\(appStoreID)?mt=8"
    let url = NSURL(string: urlString)
    UIApplication.sharedApplication().openURL(url!)
  }
  
  func learn() {
    let urlString = "http://www.raywenderlich.com/flappy-felipe"
    let url = NSURL(string: urlString)
    UIApplication.sharedApplication().openURL(url!)
  }
}