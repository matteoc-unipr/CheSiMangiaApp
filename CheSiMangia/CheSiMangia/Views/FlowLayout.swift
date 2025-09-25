//
//  FlowLayout.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//


import SwiftUI

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content
    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        VStack {
            generateLayout()
        }
        .frame(height: totalHeight)
    }

    private func generateLayout() -> some View {
        GeometryReader { geo in
            self.generate(in: geo)
        }
    }

    private func generate(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(Array(items), id: \.self) { item in
                content(item)
                    .padding(4)
                    .alignmentGuide(.leading) { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { d in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { totalHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { newValue in
                        totalHeight = newValue
                    }
            }
        )
    }
}
