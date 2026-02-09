## ADDED Requirements

### Requirement: Global Window Style
The settings window SHALL adopt a custom, borderless, glassmorphism design.

#### Scenario: Window Attributes
- **WHEN** the settings window is initialized
- **THEN** it MUST have a fixed size of 800x550 pixels
- **AND** it MUST NOT have a standard system title bar
- **AND** the background MUST be a linear gradient from #1a1a2e to #0f0f23
- **AND** a background blur (High or UltraThin material) MUST be applied
- **AND** the window corners MUST be rounded with a 12px radius

### Requirement: Sidebar Navigation
The settings panel SHALL use a persistent sidebar for navigation.

#### Scenario: Sidebar Structure
- **WHEN** the user views the sidebar
- **THEN** it MUST be 200px wide
- **AND** it MUST list the following categories in order: General, Clipboard, Appearance, OCR, Shortcuts, About
- **AND** each category MUST display an SF Symbol icon and a text label
- **AND** the version number MUST be displayed at the bottom

#### Scenario: Selection State
- **WHEN** a category is selected
- **THEN** the item background MUST change to Teal (#2DD4BF) with 15% opacity
- **AND** the text color MUST change to Teal (#2DD4BF)

### Requirement: General Settings Page
The General page SHALL allow configuration of application startup behavior.

#### Scenario: Launch Options
- **WHEN** viewing the General page
- **THEN** a "Launch at login" toggle MUST be displayed
- **AND** a "Show in menu bar" toggle MUST be displayed
- **AND** toggling these MUST update the underlying application configuration immediately

### Requirement: Clipboard Settings Page
The Clipboard page SHALL manage history retention and performance settings.

#### Scenario: History Configuration
- **WHEN** viewing the Clipboard page
- **THEN** a "History Size" dropdown MUST allow selecting: 50, 100, 500, 1000, Unlimited
- **AND** a "Retention Period" dropdown MUST allow selecting: 1 day, 1 week, 1 month, Forever
- **AND** a "Clear history on exit" toggle MUST be available

#### Scenario: Danger Zone
- **WHEN** viewing the bottom of Clipboard page
- **THEN** a "Danger Zone" section MUST be visible with a red background style
- **AND** a "Clear Data..." button MUST be present
- **AND** clicking "Clear Data..." MUST show a confirmation dialog before deleting all data

### Requirement: Appearance Settings Page
The Appearance page SHALL allow customizing the visual theme.

#### Scenario: Theme Selection
- **WHEN** viewing the Appearance page
- **THEN** three theme cards (System, Dark, Light) MUST be displayed horizontally
- **AND** each card MUST show a preview graphic and a radio button
- **AND** clicking a card MUST update the app's appearance immediately

#### Scenario: Blur Intensity
- **WHEN** viewing the Appearance page
- **THEN** a slider MUST be available to adjust "Blur Intensity" from 0% to 100%

### Requirement: OCR Settings Page
The OCR page SHALL configure optical character recognition features.

#### Scenario: OCR Configuration
- **WHEN** viewing the OCR page
- **THEN** an "Enable OCR" master toggle MUST be present
- **AND** a multi-select list of languages (English, Chinese, etc.) MUST be available
- **AND** a "Confidence Threshold" slider (0.0 - 1.0) MUST be available
- **AND** a "Recognition Model" dropdown (Fast vs Accurate) MUST be available

### Requirement: Shortcuts Settings Page
The Shortcuts page SHALL manage global and in-app keyboard shortcuts.

#### Scenario: Global Hotkey
- **WHEN** viewing the Shortcuts page
- **THEN** a shortcut recorder MUST allow setting the "Toggle Pasty2" global hotkey
- **AND** the current hotkey (e.g., ⌘⇧V) MUST be displayed

### Requirement: About Page
The About page SHALL display application information.

#### Scenario: Content Display
- **WHEN** viewing the About page
- **THEN** the App Icon MUST be displayed prominently
- **AND** the App Name and Version (with Build number) MUST be shown
- **AND** links to Website, Support, and License MUST be clickable
