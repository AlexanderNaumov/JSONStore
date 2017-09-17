//
//  JSONStore.swift
//  JSONStore
//
//  Created by Alexander Naumov on 17.09.17.
//  Copyright © 2017 Alexander Naumov. All rights reserved.
//

import Foundation
import CoreData

class JSONStore: NSAtomicStore {
    
    static let type = "JSONStore"
    private static let uuid = UUID().uuidString
    
    private var _metadata: [String : Any] = [NSStoreTypeKey: JSONStore.type, NSStoreUUIDKey: JSONStore.uuid]
    
    override var metadata: [String : Any]! {
        get { return _metadata }
        set { _metadata = newValue }
    }
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZ"
        return dateFormatter
    }()
    
    override func newReferenceObject(for managedObject: NSManagedObject) -> Any {
        return UUID().uuidString
    }
    
    override func newCacheNode(for managedObject: NSManagedObject) -> NSAtomicStoreCacheNode {
        let node = NSAtomicStoreCacheNode(objectID: managedObject.objectID)
        updateCacheNode(node, from: managedObject)
        return node
    }
    
    private func getNode(for objectID: NSManagedObjectID) -> NSAtomicStoreCacheNode {
        if let node = cacheNode(for: objectID) {
            return node
        } else {
            let node = NSAtomicStoreCacheNode(objectID: objectID)
            addCacheNodes([node])
            return node
        }
    }
    
    override func updateCacheNode(_ node: NSAtomicStoreCacheNode, from managedObject: NSManagedObject) {
        let entity = managedObject.entity
        if node.propertyCache == nil { node.propertyCache = NSMutableDictionary() }
        node.propertyCache!.addEntries(from: managedObject.dictionaryWithValues(forKeys: Array(entity.attributesByName.keys)))
        node.propertyCache!.addEntries(from: managedObject.dictionaryWithValues(forKeys: Array(entity.relationshipsByName.keys)).mapValues { value -> Any in
            switch value {
            case let object as NSManagedObject:
                return getNode(for: object.objectID)
            case let objects as Set<NSManagedObject>:
                return Set(objects.map { getNode(for: $0.objectID) })
            default:
                return NSNull()
            }
        })
    }
    
    override func load() throws {
        guard FileManager.default.fileExists(atPath: url!.relativePath) else { return }
        
        let jsonData = try Data(contentsOf: url!)
        let array = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
        
        let managedObjectModel = persistentStoreCoordinator!.managedObjectModel
        
        let nodes = array.map { dict -> NSAtomicStoreCacheNode in
            var dict = dict
            
            let entityName = dict.removeValue(forKey: "entityName") as! String
            let referenceId = dict.removeValue(forKey: "referenceId") as! String
            
            let entity = managedObjectModel.entitiesByName[entityName]!
            let node = NSAtomicStoreCacheNode(objectID: objectID(for: entity, withReferenceObject: referenceId))
            
            let objects = dict.flatMap { (key, value) -> (String, Any)? in
                if let attribute = entity.attributesByName[key] {
                    switch (attribute.attributeType, value) {
                    case (.integer16AttributeType, _), (.integer32AttributeType, _), (.integer64AttributeType, _), (.doubleAttributeType, _), (.floatAttributeType, _), (.booleanAttributeType, _):
                        return (key, value)
                    case (.stringAttributeType, let str as String):
                        return (key, str)
                    case (.dateAttributeType, let str as String):
                        return (key, dateFormatter.date(from: str)!)
                    case (.binaryDataAttributeType, let str as String):
                        return (key, Data(base64Encoded: str)!)
                    default: break
                    }
                } else if let relationship = entity.relationshipsByName[key] {
                    switch value {
                    case let ids as [String]:
                        return (key, Set(ids.map { NSAtomicStoreCacheNode(objectID: objectID(for: relationship.destinationEntity!, withReferenceObject: $0)) }))
                    case let id as String:
                        return (key, NSAtomicStoreCacheNode(objectID: objectID(for: relationship.destinationEntity!, withReferenceObject: id)))
                    default: break
                    }
                }
                return nil
            }
            node.propertyCache = NSMutableDictionary(objects: objects.map { $0.1 }, forKeys: objects.map { $0.0 as NSString })
            return node
        }
        addCacheNodes(Set(nodes))
    }
    
    override func save() throws {
        let array = cacheNodes().map { node -> [String: Any] in
            var result = (node.propertyCache as! [String: Any]).mapValues { value -> Any in
                switch value {
                case is String, is Int16, is Int32, is Int64, is Double, is Float, is Bool, is NSNull:
                    return value
                case let date as Date:
                    return dateFormatter.string(from: date)
                case let data as Data:
                    return data.base64EncodedString()
                case let node as NSAtomicStoreCacheNode:
                    return referenceObject(for: node.objectID)
                case let nodes as Set<NSAtomicStoreCacheNode>:
                    return nodes.map { referenceObject(for: $0.objectID) }
                default:
                    fatalError()
                }
            }
            result["entityName"] = node.objectID.entity.name!
            result["referenceId"] = referenceObject(for: node.objectID)
            return result
        }
        let jsonData = try JSONSerialization.data(withJSONObject: array)
        try jsonData.write(to: url!)
    }
}
