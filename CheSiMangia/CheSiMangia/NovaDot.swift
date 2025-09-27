//
//  NovaDot.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 27/09/25.
//


import SwiftUI

struct NovaDot: View {
    let level: Int // 1...4

    private var color: Color {
        switch level {
        case 1: return Color(red: 0.0, green: 1.0, blue: 0.0)   // verde fluorescente
        case 2: return Color(red: 0.09, green: 0.53, blue: 0.25) // verde scuro
        case 3: return Color(red: 0.98, green: 0.85, blue: 0.25) // giallo
        case 4: return Color(red: 0.99, green: 0.61, blue: 0.20) // arancione → vuoi rosso? metti (0.86,0.23,0.19)
        default: return .gray.opacity(0.4)
        }
    }

    var body: some View {
        Text("\(level)")
            .font(.caption).bold()
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .accessibilityLabel("NOVA \(level)")
    }
}
