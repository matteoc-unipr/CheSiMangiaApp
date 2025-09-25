//
//  Persistence.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//

import CoreData

final class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CheSiMangia")
        if inMemory { container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null") }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.loadPersistentStores { _, error in if let error = error { fatalError("Unresolved error: \(error)") } }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
