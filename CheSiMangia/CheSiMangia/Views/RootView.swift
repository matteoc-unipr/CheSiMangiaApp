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
            SettingsView().tabItem { Label("Preferenze", systemImage: "slider.horizontal.3") }
        }
    }
}
