//
//  ViewController.swift
//  ARKitWorkingWithWorldMapData
//

import UIKit
import ARKit

class ViewController: UIViewController, UINavigationControllerDelegate {
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var label: UILabel!
    
    var scnNode: SCNNode?
    var selectedImage: UIImage?
    var location: CGPoint?
    var imagesDict =  [String:UIImage]()
    
    var worldMapURL: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("worldMapURL")
        } catch {
            fatalError("Error getting world map URL from document directory.")
        }
    }()
    
    var imageURL: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("imageURL")
        } catch {
            fatalError("Error getting image  URL from document directory.")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        configureLighting()
        addTapGestureToSceneView()
    }
    
    func addTapGestureToSceneView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didReceiveTapGesture(_:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    func generateSphereNode() -> SCNNode {
        let sphere = SCNSphere(radius: 0.05)
        let sphereNode = SCNNode()
        sphereNode.position.y += Float(sphere.radius)
        sphereNode.geometry = sphere
        return sphereNode
    }
    
    func generatePlaneNode() -> SCNNode {
        let planeGeometry = SCNPlane(width: 0.5, height: 0.5)

        //b. Set's It's Contents To The Picked Image
        planeGeometry.firstMaterial?.diffuse.contents = self.correctlyOrientated(self.selectedImage!)

        //c. Set The Geometry & Add It To The Scene
        let planeNode = SCNNode()
        planeNode.geometry = planeGeometry
        planeNode.position = SCNVector3(0, 0, -0.5)

        return planeNode
    }
    
    func generateBoxNodeforAnchor(anchor:ARAnchor) -> SCNNode {
        let box = SCNBox(width: 0.45, height: 0.45, length: 0.45, chamferRadius: 0.0)
        
        let material = SCNMaterial()
      //  material.diffuse.contents = self.selectedImage
        material.diffuse.contents = self.imagesDict[anchor.identifier.uuidString]

        let node = SCNNode()
        node.geometry = box
        node.geometry?.materials = [material]
        node.position = SCNVector3(x: 0, y: 0.1, z: -0.5)
        
        return node
    }
    
    func configureLighting() {
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetTrackingConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    @IBAction func resetBarButtonItemDidTouch(_ sender: UIBarButtonItem) {
        resetTrackingConfiguration()
    }
    
    @IBAction func saveBarButtonItemDidTouch(_ sender: UIBarButtonItem) {
        self.saveWorldmapAndImageMap()
    }
    
    func saveWorldmapAndImageMap() {
        sceneView.session.getCurrentWorldMap { (worldMap, error) in
            guard let worldMap = worldMap else {
                return self.setLabel(text: "Error getting current world map.")
            }
            
            do {
                try self.archive(worldMap: worldMap, imageData: self.imagesDict)
                DispatchQueue.main.async {
                    self.setLabel(text: "World map is saved.")
                }
            } catch {
                fatalError("Error saving world map: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func loadBarButtonItemDidTouch(_ sender: UIBarButtonItem) {
        guard let worldMapData = retrieveWorldMapData(from: worldMapURL),
              let worldMap = unarchiveWorldMap(worldMapData: worldMapData) else { return }
        
        guard let imageData = retrieveImageData(from: self.imageURL),
              let imageData = unarchiveImageData(imageData: imageData) else { return }
        
        self.imagesDict.removeAll()
        self.imagesDict = imageData
    
        resetTrackingConfiguration(with: worldMap)
    }
    
    func resetTrackingConfiguration(with worldMap: ARWorldMap? = nil) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        if let worldMap = worldMap {
            configuration.initialWorldMap = worldMap
            setLabel(text: "Found saved world map.")
        } else {
            setLabel(text: "Move camera around to map your surrounding space.")
        }
        
        sceneView.debugOptions = [.showFeaturePoints]
        sceneView.session.run(configuration, options: options)
    }
    
    func setLabel(text: String) {
        label.text = text
    }
    
    func archive(worldMap: ARWorldMap, imageData: [String:UIImage]) throws {
        try? self.archiveWorldMap(worldMap: worldMap)
        try? self.archiveImageMap(imageData: imageData)
    }
    
    func archiveWorldMap(worldMap: ARWorldMap) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        try data.write(to: self.worldMapURL, options: [.atomic])
    }
    
    func archiveImageMap(imageData:[String:UIImage]) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: imageData, requiringSecureCoding: true)
        try data.write(to: self.imageURL, options: [.atomic])
    }

    func retrieveWorldMapData(from url: URL) -> Data? {
        do {
            return try Data(contentsOf: self.worldMapURL)
        } catch {
            self.setLabel(text: "Error retrieving world map data.")
            return nil
        }
    }
    
    func retrieveImageData(from url: URL) -> Data? {
        do {
            return try Data(contentsOf: self.imageURL)
        } catch {
            self.setLabel(text: "Error retrieving image map data.")
            return nil
        }
    }
    
    func unarchiveWorldMap(worldMapData data: Data) -> ARWorldMap? {
        guard let unarchievedObject = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data),
            let worldMap = unarchievedObject else { return nil }
        return worldMap
    }
    
    func unarchiveImageData(imageData: Data) -> [String:UIImage]? {
        guard let un = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(imageData),
              let imageData = un else { return nil }
        return imageData as? [String : UIImage]
    }
}


extension ViewController: ARSCNViewDelegate ,UIImagePickerControllerDelegate {
    
    @objc func didReceiveTapGesture(_ sender: UITapGestureRecognizer) {
        self.location = sender.location(in: self.sceneView)
        
        DispatchQueue.main.async {
            self.selectPhotoFromGallery()
        }
        
//        let location = sender.location(in: self.sceneView)
//        print(location)
//        guard let hitTestResult = self.sceneView.hitTest(location, types: [.featurePoint, .estimatedHorizontalPlane]).first
//        else { return }
//
//        let anchor = ARAnchor(transform: hitTestResult.worldTransform)
//        self.sceneView.session.add(anchor: anchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard !(anchor is ARPlaneAnchor) else { return }
        //let sphereNode = generateSphereNode()
        //print("Called with anchor and Node", node, anchor)
        let sphereNode = generateBoxNodeforAnchor(anchor: anchor)
        
        //self.scnNode = node
//        DispatchQueue.main.async {
//            self.selectPhotoFromGallery()
//        }
        
        //let planeNode = self.generatePlaneNode()
        
        DispatchQueue.main.async {
            node.addChildNode(sphereNode)
            //node.addChildNode(planeNode)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage  {
            picker.dismiss(animated: true) {
                self.selectedImage = selectedImage
                guard let hitTestResult = self.sceneView.hitTest(self.location!, types: [.featurePoint, .estimatedHorizontalPlane]).first
                else { return }
                
                let anchor = ARAnchor(transform: hitTestResult.worldTransform)
                
                //Add images to Dictionary
                self.imagesDict[anchor.identifier.uuidString] =  self.selectedImage!
                self.sceneView.session.add(anchor: anchor)
            }
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true, completion: nil)
    }
    
    /// Loads The UIImagePicker & Allows Us To Select An Image
    func selectPhotoFromGallery(){
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.photoLibrary){
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.allowsEditing = true
            imagePicker.sourceType = UIImagePickerController.SourceType.photoLibrary
            self.present(imagePicker, animated: true, completion: nil)
        }

    }
    
    /// Correctly Orientates A UIImage
    ///
    /// - Parameter image: UIImage
    /// - Returns: UIImage?
    func correctlyOrientated(_ image: UIImage) -> UIImage {
        if (image.imageOrientation == .up) { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        image.draw(in: rect)

        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return normalizedImage
    }
}

extension float4x4 {
    var translation: float3 {
        let translation = self.columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}

extension UIColor {
    open class var transparentWhite: UIColor {
        return UIColor.white.withAlphaComponent(0.70)
    }
}
