//
//  NutriScoreDot.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 27/09/25.
//


import SwiftUI

struct NutriScoreDot: View {
    let grade: String  // atteso: "A"..."E"

    private var color: Color {
        switch grade.uppercased() {
        case "A": return Color(red: 0.0, green: 1.0, blue: 0.0) // verde fluo
        case "B": return Color(red: 0.09, green: 0.53, blue: 0.25) // verde scuro
        case "C": return Color(red: 0.98, green: 0.85, blue: 0.25) // giallo
        case "D": return Color(red: 0.99, green: 0.61, blue: 0.20) // arancione
        case "E": return Color(red: 0.86, green: 0.23, blue: 0.19) // rosso
        default:  return .gray.opacity(0.4)
        }
    }

    var body: some View {
        Text(grade.uppercased())
            .font(.caption).bold()
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .accessibilityLabel("Nutri-Score \(grade.uppercased())")
    }
}
