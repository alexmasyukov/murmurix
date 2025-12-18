//
//  RecordingComponents.swift
//  Murmurix
//

import SwiftUI

// MARK: - Shared Styles

struct FloatingCapsuleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(height: 28)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.9))
            )
    }
}

// MARK: - Shared Components

struct CancelButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.white.opacity(0.2)))
        }
        .buttonStyle(.plain)
    }
}
