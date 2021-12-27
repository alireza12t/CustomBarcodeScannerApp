//
//  ViewController.swift
//  Test
//
//  Created by Alireza on 12/23/21.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var outputLabel: UILabel!
    @IBOutlet weak var outputTitleLabel: UILabel!
    /// Camera view with custom buttons.
    public private(set) lazy var cameraViewController: CameraViewController = .init()
    
    /// The current controller's status mode.
    private var status: Status = Status(state: .scanning) {
        didSet {
            changeStatus(from: oldValue, to: status)
        }
    }
    /// Flag to lock session from capturing.
    private var locked = false
    /// Flag to check if view controller is currently on screen
    private var isVisible = false
    
    
    /// `AVCaptureMetadataOutput` metadata object types.
    public var metadata = AVMetadataObject.ObjectType.barcodeScannerMetadata {
        didSet {
            cameraViewController.metadata = metadata
        }
    }
    /// When the flag is set to `true` the screen is flashed on barcode scan.
    /// Defaults to true.
    public var shouldSimulateFlash = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addCameraVC()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraViewController.shouldScan = true
        setupCameraConstraints()
        isVisible = true
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isVisible = false
    }
    
    func addCameraVC() {
        cameraViewController.metadata = metadata
        cameraViewController.delegate = self
        add(childViewController: cameraViewController)
    }
    
    func setupCameraConstraints() {
        cameraViewController.view.translatesAutoresizingMaskIntoConstraints = false
        cameraViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20).isActive = true
        cameraViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
        cameraViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20).isActive = true
        cameraViewController.view.bottomAnchor.constraint(equalTo: outputTitleLabel.topAnchor, constant: -20).isActive = true
    }
}

extension ViewController {
    /// Resets the current state.
    private func resetState() {
        locked = status.state == .processing
        if status.state == .scanning {
            cameraViewController.startCapturing()
        } else {
            cameraViewController.stopCapturing()
        }
    }
    
    private func changeStatus(from oldValue: Status, to newValue: Status) {
        guard newValue.state != .notFound else {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
                self.status = Status(state: .scanning)
            }
            return
        }
                
        let animatedTransition = newValue.state == .processing
        || oldValue.state == .processing
        || oldValue.state == .notFound
        let duration = newValue.animated && animatedTransition ? 0.5 : 0.0
        let delayReset = oldValue.state == .processing || oldValue.state == .notFound
        
        if !delayReset {
            resetState()
        }
        
        //      if newValue.state != .processing {
        //        expandedConstraints.deactivate()
        //        collapsedConstraints.activate()
        //      } else {
        //        collapsedConstraints.deactivate()
        //        expandedConstraints.activate()
        //      }
        //
        //      messageViewController.status = newValue
        
        UIView.animate(
            withDuration: duration,
            animations: ({
                self.view.layoutIfNeeded()
            }),
            completion: ({ [weak self] _ in
                if delayReset {
                    self?.resetState()
                }
                
                //          self?.messageView.layer.removeAllAnimations()
                //          if self?.status.state == .processing {
                //            self?.messageViewController.animateLoading()
                //          }
            }))
    }
    
    /**
     Simulates flash animation.
     - Parameter processing: Flag to set the current state to `.processing`.
     */
    private func animateFlash(whenProcessing: Bool = false) {
        guard shouldSimulateFlash else {
            if whenProcessing {
                self.status = Status(state: .processing)
            }
            return
        }
        
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = UIColor.white
        flashView.alpha = 1
        
        view.addSubview(flashView)
        view.bringSubviewToFront(flashView)
        
        UIView.animate(
            withDuration: 0.2,
            animations: ({
                flashView.alpha = 0.0
            }),
            completion: ({ [weak self] _ in
                flashView.removeFromSuperview()
                
                if whenProcessing {
                    self?.status = Status(state: .processing)
                }
            }))
    }
}

// MARK: - CameraViewControllerDelegate
extension ViewController: CameraViewControllerDelegate {
    func cameraViewControllerDidSetupCaptureSession(_ controller: CameraViewController) {
        status = Status(state: .scanning)
    }
    
    func cameraViewControllerDidFailToSetupCaptureSession(_ controller: CameraViewController) {
        status = Status(state: .unauthorized)
    }
    
    func cameraViewController(_ controller: CameraViewController, didReceiveError error: Error) {
        //    errorDelegate?.scanner(self, didReceiveError: error)
    }
    
    func cameraViewControllerDidTapSettingsButton(_ controller: CameraViewController) {
        DispatchQueue.main.async {
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }
    }
    
    func cameraViewController(_ controller: CameraViewController, didOutput metadataObjects: [AVMetadataObject]) {
        guard !locked && isVisible else { return }
        guard !metadataObjects.isEmpty else { return }
        
        guard
            let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject,
            var code = metadataObj.stringValue,
            metadata.contains(metadataObj.type)
        else { return }
        
        var rawType = metadataObj.type.rawValue
        
        // UPC-A is an EAN-13 barcode with a zero prefix.
        // See: https://stackoverflow.com/questions/22767584/ios7-barcode-scanner-api-adds-a-zero-to-upca-barcode-format
        if metadataObj.type == AVMetadataObject.ObjectType.ean13 && code.hasPrefix("0") {
            code = String(code.dropFirst())
            rawType = AVMetadataObject.ObjectType.upca.rawValue
        }
        
        if metadataObj.type == .code128 {
            outputLabel.text = code
            cameraViewController.shouldScan = false
        }
        //    codeDelegate?.scanner(self, didCaptureCode: code, type: rawType)
    }
}
