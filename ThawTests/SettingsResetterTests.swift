//
//  SettingsResetterTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation
import Testing
@testable import Thaw

/// Covers ``AppSettings``' reset surface: every reset must return the
/// properties it owns to `Defaults.DefaultValue`, and must not reach outside
/// its own pane.
///
/// `AppSettings` is built without an `AppState`, so the `appState?.…` hops in
/// `resetAppearance()` and `resetAdvanced()` are no-ops here — those lines
/// still execute, but the assertions below only cover the settings the
/// resetter owns directly.
///
/// The sub-models persist on `didSet` and `Defaults` is hardcoded to
/// `.standard`, so the suite snapshots and restores the app's whole
/// persistent domain rather than the individual keys each reset touches.
@MainActor
@Suite("Settings resetter", .serialized)
final class SettingsResetterTests {
    private let domainName: String
    private let savedDomain: [String: Any]?

    init() {
        domainName = Bundle.main.bundleIdentifier ?? "com.stonerl.Thaw"
        savedDomain = UserDefaults.standard.persistentDomain(forName: domainName)
    }

    /// Isolated so the non-Sendable domain snapshot is reachable here;
    /// the suite is already `@MainActor`.
    @MainActor
    deinit {
        if let savedDomain {
            UserDefaults.standard.setPersistentDomain(savedDomain, forName: domainName)
        } else {
            UserDefaults.standard.removePersistentDomain(forName: domainName)
        }
    }

    // MARK: General

    @Test("Resetting General restores its defaults")
    func resetGeneralRestoresDefaults() {
        let settings = AppSettings()
        settings.general.showIceIcon = !Defaults.DefaultValue.showIceIcon
        settings.general.showOnHover = !Defaults.DefaultValue.showOnHover
        settings.general.autoRehide = !Defaults.DefaultValue.autoRehide
        settings.general.rehideInterval = Defaults.DefaultValue.rehideInterval + 42

        settings.resetGeneral()

        #expect(settings.general.showIceIcon == Defaults.DefaultValue.showIceIcon)
        #expect(settings.general.showOnHover == Defaults.DefaultValue.showOnHover)
        #expect(settings.general.autoRehide == Defaults.DefaultValue.autoRehide)
        #expect(settings.general.rehideInterval == Defaults.DefaultValue.rehideInterval)
        #expect(settings.general.lastCustomIceIcon == nil)
    }

    @Test("Resetting General leaves Advanced alone")
    func resetGeneralDoesNotTouchAdvanced() {
        let settings = AppSettings()
        let changed = !Defaults.DefaultValue.hideApplicationMenus
        settings.advanced.hideApplicationMenus = changed

        settings.resetGeneral()

        #expect(settings.advanced.hideApplicationMenus == changed)
    }

    // MARK: Advanced

    @Test("Resetting Advanced restores its defaults")
    func resetAdvancedRestoresDefaults() {
        let settings = AppSettings()
        settings.advanced.hideApplicationMenus = !Defaults.DefaultValue.hideApplicationMenus
        settings.advanced.enableAlwaysHiddenSection = !Defaults.DefaultValue.enableAlwaysHiddenSection
        settings.advanced.showMenuBarTooltips = !Defaults.DefaultValue.showMenuBarTooltips
        settings.advanced.tooltipDelay = Defaults.DefaultValue.tooltipDelay + 5

        settings.resetAdvanced()

        #expect(settings.advanced.hideApplicationMenus == Defaults.DefaultValue.hideApplicationMenus)
        #expect(settings.advanced.enableAlwaysHiddenSection == Defaults.DefaultValue.enableAlwaysHiddenSection)
        #expect(settings.advanced.showMenuBarTooltips == Defaults.DefaultValue.showMenuBarTooltips)
        #expect(settings.advanced.tooltipDelay == Defaults.DefaultValue.tooltipDelay)
    }

    @Test("Resetting Advanced restores the sanitized search section order")
    func resetAdvancedRestoresSearchSectionOrder() {
        let settings = AppSettings()
        settings.advanced.searchSectionOrder = []

        settings.resetAdvanced()

        let expected = AdvancedSettings.sanitizedSearchSectionOrder(
            from: Defaults.DefaultValue.searchSectionOrder
        )
        #expect(settings.advanced.searchSectionOrder == expected)
        #expect(!settings.advanced.searchSectionOrder.isEmpty)
    }

    // MARK: Hotkeys

    @Test("Resetting Hotkeys clears every binding")
    func resetHotkeysClearsBindings() throws {
        let settings = AppSettings()
        let hotkey = try #require(settings.hotkeys.hotkey(withAction: .toggleHiddenSection))
        hotkey.keyCombination = KeyCombination(key: .f19, modifiers: [.command, .shift])

        settings.resetHotkeys()

        #expect(settings.hotkeys.hotkeys.allSatisfy { $0.keyCombination == nil })
    }

    // MARK: Display

    @Test("Resetting Display restores its defaults")
    func resetDisplayRestoresDefaults() {
        let settings = AppSettings()
        settings.displaySettings.configurations = [
            "UUID-A": .defaultConfiguration.withItemSpacingOffset(9),
        ]
        settings.displaySettings.globalConfiguration = .defaultConfiguration.withItemSpacingOffset(-9)
        settings.displaySettings.confirmSpacingRelaunch = !Defaults.DefaultValue.confirmSpacingRelaunch
        // Default is `.activeProfile`, so this has to be moved off it for the
        // assertion below to mean anything.
        settings.displaySettings.unconfirmedSpacingProfileScope = .allProfiles

        settings.resetDisplay()

        #expect(settings.displaySettings.configurations == Defaults.DefaultValue.displayIceBarConfigurations)
        #expect(settings.displaySettings.globalConfiguration == Defaults.DefaultValue.globalDisplayConfiguration)
        #expect(settings.displaySettings.confirmSpacingRelaunch == Defaults.DefaultValue.confirmSpacingRelaunch)
        #expect(
            settings.displaySettings.unconfirmedSpacingProfileScope
                == Defaults.DefaultValue.unconfirmedSpacingProfileScope
        )
    }

    // MARK: All

    @Test("Resetting everything covers every pane at once")
    func resetAllRestoresEveryPane() {
        let settings = AppSettings()
        settings.general.showOnHover = !Defaults.DefaultValue.showOnHover
        settings.advanced.hideApplicationMenus = !Defaults.DefaultValue.hideApplicationMenus
        settings.displaySettings.confirmSpacingRelaunch = !Defaults.DefaultValue.confirmSpacingRelaunch

        settings.resetAllSettingsToDefaults()

        #expect(settings.general.showOnHover == Defaults.DefaultValue.showOnHover)
        #expect(settings.advanced.hideApplicationMenus == Defaults.DefaultValue.hideApplicationMenus)
        #expect(settings.displaySettings.confirmSpacingRelaunch == Defaults.DefaultValue.confirmSpacingRelaunch)
        #expect(settings.hotkeys.hotkeys.allSatisfy { $0.keyCombination == nil })
    }

    @Test("Resetting is idempotent")
    func resetIsIdempotent() {
        let settings = AppSettings()
        settings.resetAllSettingsToDefaults()
        let firstPass = settings.general.showOnHover

        settings.resetAllSettingsToDefaults()

        #expect(settings.general.showOnHover == firstPass)
        #expect(settings.general.showOnHover == Defaults.DefaultValue.showOnHover)
    }
}
