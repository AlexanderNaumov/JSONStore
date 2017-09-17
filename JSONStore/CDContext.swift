//
//  CDContext.swift
//  JSONStore
//
//  Created by Alexander Naumov on 17.09.17.
//  Copyright © 2017 Alexander Naumov. All rights reserved.
//

import Foundation
import CoreData

typealias CDContext = NSManagedObjectContext

extension CDContext {
    private class PersistentStoreCoordinator: NSPersistentStoreCoordinator {
        
        static let `default` = PersistentStoreCoordinator()
        
        lazy var viewContext: CDContext = {
            let context = CDContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = self
            return context
        }()
        
        init() {
            let url = Bundle.main.url(forResource: "JSONStore", withExtension: "momd")!
            super.init(managedObjectModel: NSManagedObjectModel(contentsOf: url)!)
            
            let filePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/db.json"
            print("file path: \(filePath)")
            NSPersistentStoreCoordinator.registerStoreClass(JSONStore.self, forStoreType: JSONStore.type)
            do {
                try addPersistentStore(ofType: JSONStore.type, configurationName: nil, at: URL(fileURLWithPath: filePath), options: nil)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
    
    static var view: CDContext {
        return PersistentStoreCoordinator.default.viewContext
    }
}
