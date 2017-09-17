//
//  ViewController.swift
//  JSONStore
//
//  Created by Alexander Naumov on 17.09.17.
//  Copyright © 2017 Alexander Naumov. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let context = CDContext.view
        
        for i in (0..<2) {
            let user = User(context: context)
            user.name = "User: \(i)"
            for i in (0..<2) {
                let child = User(context: context)
                child.name = "Child: \(i)"
                child.parent = user
            }
        }
        
        try? context.save()
    }
}

