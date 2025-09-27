//
//  CheSiMangiaApp.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//

import SwiftUI

@main
struct CheSiMangiaApp: App {
    let persistence = PersistenceController.shared
    @StateObject var vm = AppViewModel()
    var body: some Scene {
        WindowGroup {
                    RootView()
                        .environmentObject(vm)
                        // 🔑 qui metti il contesto di Core Data
                        .environment(\.managedObjectContext, persistence.container.viewContext)
                }
    }
}
