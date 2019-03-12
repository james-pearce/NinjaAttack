/// Copyright (c) 2018 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import SpriteKit

//calculations to determine the destination for firing projectiles
//methods to add and subtract vectors
//these make use of Swift operator overloading
//standard implementation of vector maths functions
func +(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func -(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

func *(point: CGPoint, scalar: CGFloat) -> CGPoint {
  return CGPoint(x: point.x * scalar, y: point.y * scalar)
}

func /(point: CGPoint, scalar: CGFloat) -> CGPoint {
  return CGPoint(x: point.x / scalar, y: point.y / scalar)
}

#if !(arch(x86_64) || arch(arm64))
func sqrt(a: CGFloat) -> CGFloat {
  return CGFloat(sqrtf(Float(a)))
}
#endif

extension CGPoint {
  func length() -> CGFloat {
    return sqrt(x*x + y*y)
  }
  
  func normalized() -> CGPoint {
    return self / length()
  }
}

struct PhysicsCategory {
  static let none : UInt32 = 0
  static let all  : UInt32 = UInt32.max
  static let monster : UInt32 = 0b1
  static let projectile : UInt32 = 0b10
} // 32-bit integer acting as a bitmask ==> 32 categories

class GameScene: SKScene {
  
  let player = SKSpriteNode(imageNamed: "player") // pass the name of the image
  
  var monsterDestroyed = 0
  
  override func didMove(to view: SKView) {
    backgroundColor = SKColor.white
    player.position = CGPoint(x: size.width * 0.1, y: size.height * 0.5)
    addChild(player) // makes it appear on the scene etc.
    physicsWorld.gravity = .zero // no gravity
    physicsWorld.contactDelegate = self // scene is the delegate to be notified on a collision
    run(SKAction.repeatForever(
      SKAction.sequence(
        [SKAction.run(addMonster),
         SKAction.wait(forDuration: 1.0)
      ])
    ))
    let backgroundMusic = SKAudioNode(fileNamed: "background-music-aac.caf")
    backgroundMusic.autoplayLooped = true
    addChild(backgroundMusic)
  } // run a sequence of actions to call a block of code, then wait for 1 second.
  
  func random() -> CGFloat {
    return CGFloat(Float(arc4random()) / 0xFFFFFFFF)
  }
  
  func random(min:CGFloat, max: CGFloat) -> CGFloat {
    return random() * (max - min) + min
  }
  
  // more advanced random number functionality is available in random number
  // APIs in GameplayKit
  
  func addMonster() {
    //create sprite
    let monster = SKSpriteNode(imageNamed: "monster")
    monster.physicsBody = SKPhysicsBody(rectangleOf: monster.size) //create a physics body for the sprite
    monster.physicsBody?.isDynamic = true //not controlled by the physics engine
    monster.physicsBody?.categoryBitMask = PhysicsCategory.monster
    monster.physicsBody?.contactTestBitMask = PhysicsCategory.projectile //what categories to notify on collision
    monster.physicsBody?.collisionBitMask = PhysicsCategory.none //set to pass through not bounce off
    
    //determine where to spawn the monster along the Y axis
    let actualY = random (min: monster.size.height/2, max: size.height - monster.size.height/2)
    
    //position the monster slightly off-screen along the right edge,
    //and along a random position along the Y axis as calculated above
    monster.position = CGPoint(x: size.width + monster.size.width/2, y: actualY)
    
    //add the monster to the scene
    addChild(monster)
    
    //determine the speed of the monster
    let actualDuration = random(min: CGFloat(2.0), max: CGFloat(4.0))
    
    //create the actions
    let actionMove = SKAction.move(to: CGPoint(x: -monster.size.width/2, y: actualY), duration: TimeInterval(actualDuration)) // move off-screen to the left, randomly between 2 and 4 seconds
    let actionMoveDone = SKAction.removeFromParent() // removes a node from its parent, deleting it from the scene
    let loseAction = SKAction.run() { [weak self] in
      guard let `self` = self else { return }
      let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
      let gameOverScene = GameOverScene(size: self.size, won: false)
      self.view?.presentScene(gameOverScene, transition: reveal)
    }
    monster.run(SKAction.sequence([actionMove, loseAction, actionMoveDone])) // chain together a sequence of actions in order, one at a time
    //displays the game over scene whena  monster goes off-screen
    
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    //choose one of the touches to work with
    guard let touch = touches.first else {
      return
    }
    run(SKAction.playSoundFileNamed("pew-pew-lei.caf", waitForCompletion: false))
    let touchLocation = touch.location(in: self) //where is the touch in the scene's coordinate system
    //set up the initial location of the projectile
    let projectile = SKSpriteNode(imageNamed: "projectile")
    projectile.position = player.position
    projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectile.size.width / 2)
    projectile.physicsBody?.isDynamic = true
    projectile.physicsBody?.categoryBitMask = PhysicsCategory.projectile
    projectile.physicsBody?.contactTestBitMask = PhysicsCategory.monster
    projectile.physicsBody?.collisionBitMask = PhysicsCategory.none
    projectile.physicsBody?.usesPreciseCollisionDetection = true
    //determine the offset of location to projectile
    let offset = touchLocation - projectile.position
    //bail out if you are shooting down or backwards
    if offset.x < 0 {return}
    //add now that position has been checked
    addChild(projectile)
    //get the direction of where to shoot
    let direction = offset.normalized()
    //make it shoot far enough to be guaranteed off screen
    let shootAmount = direction*1000
    //add the shoot amount to the current position
    let realDest = shootAmount + projectile.position
    //create the actions
    let actionMove = SKAction.move(to: realDest, duration: 2.0)
    let actionMoveDone = SKAction.removeFromParent()
    projectile.run(SKAction.sequence([actionMove, actionMoveDone]))
  }
  
  func projectileDidCollideWithMonster(projectile: SKSpriteNode, monster: SKSpriteNode) {
    print("Hit")
    projectile.removeFromParent()
    monster.removeFromParent()
    monsterDestroyed += 1
    if monsterDestroyed > 30 {
      let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
      let gameOverScene = GameOverScene(size: self.size, won: true)
      view?.presentScene(gameOverScene, transition: reveal)
    }
  }
  
}

extension GameScene: SKPhysicsContactDelegate {
  
  func didBegin(_ contact: SKPhysicsContact) {
    var firstBody: SKPhysicsBody
    var secondBody: SKPhysicsBody
    if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
      firstBody = contact.bodyA
      secondBody = contact.bodyB
    } else {
      firstBody = contact.bodyB
      secondBody = contact.bodyA
    } // sort so we know the order of bodyA and bodyB
    if ((firstBody.categoryBitMask & PhysicsCategory.monster != 0) && (secondBody.categoryBitMask & PhysicsCategory.projectile != 0)) {
      if let monster = firstBody.node as? SKSpriteNode,
        let projectile = secondBody.node as? SKSpriteNode {
        projectileDidCollideWithMonster(projectile: projectile, monster: monster)
      }
    }
  }
  
}
