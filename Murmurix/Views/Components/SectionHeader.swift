//
//  SectionHeader.swift
//  Murmurix
//

import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.gray)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }
}
