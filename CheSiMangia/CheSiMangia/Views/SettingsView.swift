//
//  SettingsView.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//


import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    var body: some View {
        Form {
            Section("Preferenze dieta & allergie") {
                Toggle("Vegetariano", isOn: Binding(get: { vm.pantry.prefs?.vegetarian ?? false }, set: { vm.pantry.prefs?.vegetarian = $0; try? vm.pantry.prefs?.managedObjectContext?.save() }))
                Toggle("Senza lattosio", isOn: Binding(get: { vm.pantry.prefs?.lactoseFree ?? false }, set: { vm.pantry.prefs?.lactoseFree = $0; try? vm.pantry.prefs?.managedObjectContext?.save() }))
                Toggle("No arachidi", isOn: Binding(get: { vm.pantry.prefs?.peanutFree ?? false }, set: { vm.pantry.prefs?.peanutFree = $0; try? vm.pantry.prefs?.managedObjectContext?.save() }))
            }
            Section("Tempo & abilità") {
                Stepper(value: Binding(get: { Int(vm.pantry.prefs?.maxMinutes ?? 30) }, set: { vm.pantry.prefs?.maxMinutes = Int16($0); try? vm.pantry.prefs?.managedObjectContext?.save() }), in: 5...120, step: 5) { Text("Tempo max: \(vm.pantry.prefs?.maxMinutes ?? 30) min") }
                Picker("Livello", selection: Binding(get: { vm.pantry.prefs?.skill ?? "beginner" }, set: { vm.pantry.prefs?.skill = $0; try? vm.pantry.prefs?.managedObjectContext?.save() })) {
                    Text("Principiante").tag("beginner"); Text("Intermedio").tag("intermediate"); Text("Avanzato").tag("advanced")
                }
            }
        }.navigationTitle("Preferenze")
    }
}