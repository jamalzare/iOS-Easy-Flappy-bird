

import UIKit
import SpriteKit

class GameViewController: UIViewController, GameSceneDelegate {
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    if let skView = self.view as? SKView {
      if skView.scene == nil {
        
        // Create the scene
        let aspectRatio  = skView.bounds.size.height / skView.bounds.size.width
        let scene = GameScene(size:CGSize(width: 320, height: 320 * aspectRatio), stateClass: MainMenuState.self, delegate: self)
        
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.showsPhysics = false
        skView.ignoresSiblingOrder = true
        
        scene.scaleMode = .AspectFill
        
        skView.presentScene(scene)
      }
    }
  }
  
  override func prefersStatusBarHidden() -> Bool {
    return true
  }
  
  func screenshot() -> UIImage {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 1.0)
    view.drawViewHierarchyInRect(view.bounds, afterScreenUpdates: true)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
  }
  
  func shareString(string: String, url: NSURL, image: UIImage) {
    let vc = UIActivityViewController(activityItems: [string, url, image], applicationActivities: nil)
    presentViewController(vc, animated: true, completion: nil)
  }
  
}