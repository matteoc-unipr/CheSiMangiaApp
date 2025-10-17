//
//  RootView.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//


import SwiftUI

struct RootView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        TabView {
            PantryView().tabItem { Label("Dispensa", systemImage: "cart") }
            GenerateView().tabItem { Label("Ricette", systemImage: "fork.knife") }
            if let prefs = vm.pantry.prefs {
                           SettingsView(prefs: prefs)
                               .environmentObject(vm)
                               .tabItem {
                                   Label("Preferenze", systemImage: "slider.horizontal.3")
                               }
                       } else {
                           ProgressView()
                               .tabItem {
                                   Label("Preferenze", systemImage: "slider.horizontal.3")
                               }
                       }        }
    }
}
