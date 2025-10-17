//
//  SettingsView.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//


import SwiftUI
import CoreData

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    @ObservedObject var prefs: CDPrefs

    var body: some View {
        Form {
            Section("Preferenze dieta & allergie") {
                Toggle("Vegetariano", isOn: Binding(
                    get: { prefs.vegetarian },
                    set: { prefs.vegetarian = $0; save() }
                ))
                Toggle("Senza lattosio", isOn: Binding(
                    get: { prefs.lactoseFree },
                    set: { prefs.lactoseFree = $0; save() }
                ))
                Toggle("No arachidi", isOn: Binding(
                    get: { prefs.peanutFree },
                    set: { prefs.peanutFree = $0; save() }
                ))
            }
            Section("Porzioni") {
                Stepper(
                    value: Binding(
                        get: { Int(prefs.servings) },
                        set: { prefs.servings = Int16($0); save() }
                    ),
                    in: 1...10
                ) {
                    Text("Porzioni: \(prefs.servings)")
                }
            }
            Section("Tempo & abilità") {
                Stepper(
                    value: Binding(
                        get: { Int(prefs.maxMinutes) },
                        set: { prefs.maxMinutes = Int16($0); save() }
                    ),
                    in: 5...120,
                    step: 5
                ) {
                    Text("Tempo max: \(prefs.maxMinutes) min")
                }

                Picker("Livello", selection: Binding(
                    get: { prefs.skill ?? "beginner" },
                    set: { prefs.skill = $0; save() }
                )) {
                    Text("Principiante").tag("beginner")
                    Text("Intermedio").tag("intermediate")
                    Text("Avanzato").tag("advanced")
                }
            }
        }
        .navigationTitle("Preferenze")
    }

    private func save() {
        // salva sul main thread; Core Data NSManagedObjectContext è già sul main nel tuo setup
        do { try prefs.managedObjectContext?.save() } catch {
            print("[PREFS][ERR] save: \(error)")
        }
    }
}
