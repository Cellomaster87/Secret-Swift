//
//  ViewController.swift
//  Secret Swift
//
//  Created by Michele Galvagno on 17/05/2019.
//  Copyright © 2019 Michele Galvagno. All rights reserved.
//

import LocalAuthentication
import UIKit

class ViewController: UIViewController {
    @IBOutlet var secret: UITextView!
    var password: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Nothing to see here"
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(saveSecretMessage), name: UIApplication.willResignActiveNotification, object: nil)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveSecretMessage))
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        if let savedPassword = KeychainWrapper.standard.string(forKey: "password") {
            password = savedPassword
        } else {
            // password not set
            let setPwdAC = UIAlertController(title: "Set password", message: "Protect your secret text with a password", preferredStyle: .alert)
            setPwdAC.addTextField { (textField) in
                textField.isSecureTextEntry = true
                textField.placeholder = "Set password"
            }
            setPwdAC.textFields?[0].isSecureTextEntry = true
            
            let setPwdAction = UIAlertAction(title: "Set password", style: .default) { [weak self, weak setPwdAC] (_) in
                guard let password = setPwdAC?.textFields?[0].text else { return }
                self?.password = password
                KeychainWrapper.standard.set(password, forKey: "password")
            }
            
            setPwdAC.addAction(setPwdAction)
            setPwdAC.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            present(setPwdAC, animated: true)
        }
    }
    
    // This method launches the authentication process to unlock the app
    @IBAction func authenticateTapped(_ sender: Any) {
        let context = LAContext()
        var error: NSError?
        
        // can we use biometric authentication or not?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Identify yourself!"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] (success, authenticationError) in
                DispatchQueue.main.async {
                    if success {
                        self?.unlockSecretMessage()
                    } else {
                        // error
                        let authFailedAC = UIAlertController(title: "Authentication failed", message: "Please enter your password to unlock the secret content", preferredStyle: .alert)
                        authFailedAC.addTextField { (textField) in
                            textField.isSecureTextEntry = true
                            textField.placeholder = "Enter password"
                        }
                        
                        let enterPwdAction = UIAlertAction(title: "Unlock", style: .default) { [weak self, weak authFailedAC] (_) in
                            guard let password = authFailedAC?.textFields?[0].text else { return }
                            
                            if password == self?.password {
                                self?.unlockSecretMessage()
                            } else {
                                let ac = UIAlertController(title: "Authentication failed", message: "You could not be verified; please try again.", preferredStyle: .alert)
                                ac.addAction(UIAlertAction(title: "OK", style: .default))
                                self?.present(ac, animated: true)
                            }
                        }
                        
                        authFailedAC.addAction(enterPwdAction)
                        self?.present(authFailedAC, animated: true)
                    }
                }
            }
        } else {
            // no biometry
            let ac = UIAlertController(title: "Biometry unavailable", message: "Your device is not configured for biometric authentication.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
    }
    
    // This method takes care of the keyboard when on screen
    @objc func adjustForKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        
        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)
        
        if notification.name == UIResponder.keyboardWillHideNotification {
            secret.contentInset = .zero
        } else {
            secret.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height - view.safeAreaInsets.bottom, right: 0)
        }
        
        secret.scrollIndicatorInsets = secret.contentInset
        
        let selectedRange = secret.selectedRange
        secret.scrollRangeToVisible(selectedRange)
    }

    // Once biometry is done, this method unlocks the app and retrieves the content
    func unlockSecretMessage() {
        secret.isHidden = false
        navigationItem.rightBarButtonItem?.isEnabled = true
        
        title = "Secret stuff!"
        
        if let text = KeychainWrapper.standard.string(forKey: "SecretMessage") {
            secret.text = text
        }
//        secret.text = KeychainWrapper.standard.string(forKey: "SecretMessage") ?? ""
    }
    
    // This method "locks" the app, i.e. hides its content
    @objc func saveSecretMessage() {
        guard secret.isHidden == false else { return }
        
        KeychainWrapper.standard.set(secret.text, forKey: "SecretMessage")
        secret.resignFirstResponder()
        secret.isHidden = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        title = "Nothing to see here"
    }
}

