//
//  BackupRestore.swift
//  KinEcosystem
//
//  Created by Elazar Yifrach on 15/10/2018.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import KinUtil

public protocol KeystoreProvider {
    func exportAccount(_ password: String) throws
    func importAccount(keystore: String, password: String) throws
    func validatePassword(_ password: String) throws
}

public typealias BRCompletionHandler = (_ success: Bool) -> ()
public typealias BREventsHandler = (_ event: BREvent) -> ()

public enum BRPhase {
    case backup
    case restore
}

public enum BREvent {
    case backup(BREventType)
    case restore(BREventType)
}

public enum BREventType {
    case nextTapped
    case passwordMismatch
    case qrMailSent
}

private enum BRPresentationType {
    case pushed
    case presented
}

private struct BRInstance {
    let presentationType: BRPresentationType
    let flowController: FlowController
    let completion: BRCompletionHandler
}

@available(iOS 9.0, *)
public class BRManager: NSObject {
    private let storeProvider: KeystoreProvider
    private var presentor: UIViewController?
    private var brInstance: BRInstance?
    
    private var navigationBarBackgroundImages: [UIBarMetrics: UIImage?]?
    private var navigationBarShadowImage: UIImage?
    
    public init(with storeProvider: KeystoreProvider) {
        self.storeProvider = storeProvider
    }
    
    /**
     Start a backup or recovery phase by pushing the view controllers onto a navigation controller.
     
     If the navigation controller has a `topViewController`, then the stack will be popped to that
     view controller upon completion. Otherwise it's up to the user to perform the final navigation.
     
     - Parameter phase: Perform a backup or restore
     - Parameter navigationController: The navigation controller being pushed onto
     - Parameter events:
     - Parameter completion:
     */
    public func start(_ phase: BRPhase,
                      pushedOnto navigationController: UINavigationController,
                      events: BREventsHandler,
                      completion: @escaping BRCompletionHandler)
    {
        guard brInstance == nil else {
            completion(false)
            return
        }
        
        let isStackEmpty = navigationController.viewControllers.isEmpty
        
        removeNavigationBarBackground(navigationController.navigationBar, shouldSave: !isStackEmpty)
        
        let flowController = createFlowController(phase: phase, keystoreProvider: storeProvider, navigationController: navigationController)
        navigationController.pushViewController(flowController.entryViewController, animated: !isStackEmpty)
        
        brInstance = BRInstance(presentationType: .pushed, flowController: flowController, completion: completion)
    }
    
    /**
     Start a backup or recovery phase by presenting the navigation controller onto a view controller.
     
     - Parameter phase: Perform a backup or restore
     - Parameter viewController: The view controller being presented onto
     - Parameter events:
     - Parameter completion:
     */
    public func start(_ phase: BRPhase,
                      presentedOn viewController: UIViewController,
                      events: BREventsHandler,
                      completion: @escaping BRCompletionHandler)
    {
        guard brInstance == nil else {
            completion(false)
            return
        }
        
        let navigationController = UINavigationController()
        removeNavigationBarBackground(navigationController.navigationBar)
        
        let flowController = createFlowController(phase: phase, keystoreProvider: storeProvider, navigationController: navigationController)
        let dismissItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissFlowCanceled))
        flowController.entryViewController.navigationItem.leftBarButtonItem = dismissItem
        navigationController.viewControllers = [flowController.entryViewController]
        viewController.present(navigationController, animated: true)
        
        brInstance = BRInstance(presentationType: .presented, flowController: flowController, completion: completion)
        presentor = viewController
    }
    
    private func createFlowController(phase: BRPhase, keystoreProvider: KeystoreProvider, navigationController: UINavigationController) -> FlowController {
        switch phase {
        case .backup:
            let controller = BackupFlowController(keystoreProvider: storeProvider, navigationController: navigationController)
            controller.delegate = self
            return controller
        case .restore:
            let controller = RestoreFlowController(keystoreProvider: storeProvider, navigationController: navigationController)
            controller.delegate = self
            return controller
        }
    }
}

// MARK: - Navigation

@available(iOS 9.0, *)
extension BRManager {
    private func flowCompleted() {
        guard let brInstance = brInstance else {
            return
        }
        
        brInstance.completion(true)
        
        switch brInstance.presentationType {
        case .presented:
            dismissFlow()
        case .pushed:
            popNavigationStackIfNeeded()
        }
        
        self.brInstance = nil
    }
    
    private func dismissFlow() {
        presentor?.dismiss(animated: true)
    }
    
    @objc private func dismissFlowCanceled() {
        guard let brInstance = brInstance else {
            return
        }
        
        brInstance.completion(false)
        dismissFlow()
        
        self.brInstance = nil
    }
    
    private func popNavigationStackIfNeeded() {
        guard let flowController = brInstance?.flowController else {
            return
        }
        
        let navigationController = flowController.navigationController
        let entryViewController = flowController.entryViewController
        
        guard let index = navigationController.viewControllers.index(of: entryViewController) else {
            return
        }
        
        if index > 0 {
            restoreNavigationBarBackground(navigationController.navigationBar)
            
            let externalViewController = navigationController.viewControllers[index - 1]
            navigationController.popToViewController(externalViewController, animated: true)
        }
    }
}

// MARK: - Flow

@available(iOS 9.0, *)
extension BRManager: BackupFlowControllerDelegate {
    func backupFlowControllerQRString(_ controller: BackupFlowController) -> String {
        return "sample string" // TODO: get passphrase
    }
    
    func backupFlowControllerDidComplete(_ controller: BackupFlowController) {
        flowCompleted()
    }
}

@available(iOS 9.0, *)
extension BRManager: RestoreFlowControllerDelegate {
    func restoreFlowControllerDidComplete(_ controller: RestoreFlowController) {
        flowCompleted()
    }
}

// MARK: - Navigation Bar Appearance

@available(iOS 9.0, *)
extension BRManager {
    private func removeNavigationBarBackground(_ navigationBar: UINavigationBar, shouldSave: Bool = false) {
        if shouldSave {
            let barMetrics: [UIBarMetrics] = [.default, .defaultPrompt, .compact, .compactPrompt]
            var navigationBarBackgroundImages = [UIBarMetrics: UIImage?]()
            
            for barMetric in barMetrics {
                navigationBarBackgroundImages[barMetric] = navigationBar.backgroundImage(for: barMetric)
            }
            
            if !navigationBarBackgroundImages.isEmpty {
                self.navigationBarBackgroundImages = navigationBarBackgroundImages
            }
            
            navigationBarShadowImage = navigationBar.shadowImage
        }
        
        navigationBar.removeBackground()
    }
    
    private func restoreNavigationBarBackground(_ navigationBar: UINavigationBar) {
        navigationBar.restoreBackground(backgroundImages: navigationBarBackgroundImages, shadowImage: navigationBarShadowImage)
        navigationBarBackgroundImages = nil
        navigationBarShadowImage = nil
    }
}