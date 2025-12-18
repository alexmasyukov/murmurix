//
//  SettingsStyles.swift
//  Murmurix
//

import SwiftUI

// MARK: - Card Style

struct SettingsCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Layout.Padding.standard)
            .padding(.vertical, Layout.Padding.vertical)
            .background(AppColors.cardBackground)
            .cornerRadius(Layout.CornerRadius.card)
            .padding(.horizontal, Layout.Padding.standard)
    }
}

extension View {
    func settingsCard() -> some View {
        modifier(SettingsCardStyle())
    }
}

// MARK: - Label Style

struct SettingsLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Typography.label)
            .foregroundColor(.white)
    }
}

struct SettingsDescriptionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Typography.description)
            .foregroundColor(.gray)
    }
}

extension View {
    func settingsLabel() -> some View {
        modifier(SettingsLabelStyle())
    }

    func settingsDescription() -> some View {
        modifier(SettingsDescriptionStyle())
    }
}

// MARK: - Common Typography

extension Text {
    func labelStyle() -> some View {
        self.font(Typography.label)
            .foregroundColor(.white)
    }

    func descriptionStyle() -> some View {
        self.font(Typography.description)
            .foregroundColor(.gray)
    }

    func captionStyle() -> some View {
        self.font(Typography.caption)
            .foregroundColor(.secondary)
    }
}
