# Pasty macOS Design Specification

**Status**: Draft
**Source**: `design-system/main-panel/v2-dark-mode.html`
**Platform**: macOS (AppKit + SwiftUI Hybrid)
**Theme**: Modern Dark Mode (Glassmorphism)

---

## 1. Design Philosophy

The design aims for a "native-plus" feel on macOS:
- **Immersive**: Uses translucency (glass) to blend with the user's desktop environment.
- **Focused**: High contrast for content, subtle backgrounds for structure.
- **Modern**: Rounded corners, smooth gradients, and clean typography.

## 2. Design Tokens

### 2.1 Colors

| Token | Value / Reference | Usage | macOS Mapping (SwiftUI) |
|-------|-------------------|-------|-------------------------|
| **Background (Window)** | `linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f0f23 100%)` | Main Window Background | `.background(LinearGradient(...))` |
| **Surface (Panel)** | `rgba(30, 30, 46, 0.85)` | Main container overlay | `.background(Color(red: 0.12, green: 0.12, blue: 0.18, opacity: 0.85))` |
| **Glass Card** | `rgba(255, 255, 255, 0.03)` | Sections, Cards | `.background(.ultraThinMaterial.opacity(0.3))` |
| **Accent Primary** | `#2DD4BF` (Teal-400) | Focus rings, Icons, Highlights | `Color.teal` or Custom Hex |
| **Accent Gradient** | `#0D9488` → `#14B8A6` | Primary Buttons | `LinearGradient(colors: [.teal, .mint], ...)` |
| **Text Primary** | `#E5E7EB` (Gray-200) | Main content | `.primary` or `Color.gray.opacity(0.9)` |
| **Text Secondary** | `#9CA3AF` (Gray-400) | Metadata, Labels | `.secondary` or `Color.gray` |
| **Text Muted** | `#6B7280` (Gray-500) | Footers, Timestamps | `.tertiary` or `Color.gray.opacity(0.6)` |
| **Border Light** | `rgba(255, 255, 255, 0.1)` | Dividers, Card borders | `.divider` or `Color.white.opacity(0.1)` |

### 2.2 Typography

Font Family: System Font (`SF Pro Text` / `SF Pro Display`)

| Style | Weight | Size | Usage |
|-------|--------|------|-------|
| **Body** | Regular | 13pt | Standard list text |
| **Body Bold** | Medium | 13pt | Highlighted text |
| **Small** | Regular | 11pt | Metadata, Timestamps |
| **Small Bold** | Semibold | 11pt | Section Headers (UPPERCASE) |
| **Code** | Mono | 12pt | Snippet previews |

### 2.3 Effects & Depth

- **Window Blur**: `backdrop-filter: blur(40px)` → `NSVisualEffectView` (HUD or Sidebar material).
- **Card Blur**: `backdrop-filter: blur(20px)` → SwiftUI `.background(.regularMaterial)`.
- **Shadows**:
    - **Panel**: `0 8px 32px rgba(0, 0, 0, 0.4)`
    - **Button**: `0 2px 8px rgba(13, 148, 136, 0.4)`

---

## 3. Layout & Components

### 3.1 Main Window Layout
- **Dimensions**: Fixed or Resizable (Prototype: 900x600).
- **Structure**:
    - **Top Bar**: Search input (Full width or centered).
    - **Split View**:
        - **Left (List)**: ~55% width. Scrollable.
        - **Right (Preview)**: ~45% width. Fixed.
    - **Status Bar**: Bottom footer for shortcuts.

### 3.2 Search Bar
- **Style**: Floating glass field.
- **Height**: ~40px (`py-2.5`).
- **State: Default**: `bg-black/30`, Border `white/10`.
- **State: Focus**: `bg-black/40`, Border `#2DD4BF`, Glow effect.
- **Icon**: Magnifying glass on left (`pl-10`).

### 3.3 List Item (Clipboard Entry)
- **Container**: `p-3.5`, `rounded-8px`.
- **States**:
    - **Normal**: Transparent.
    - **Hover**: `bg-white/6`.
    - **Selected**: `bg-[#2DD4BF]/12`, Left Border `3px solid #2DD4BF`.
- **Content**:
    - **Icon**: 32x32 rounded box. Background colored by app source (e.g., VSCode=Blue, Terminal=Gray).
    - **Title**: Truncated, Primary Text.
    - **Subtitle**: App Name • Time Ago (Secondary Text).

### 3.4 Preview Panel
- **Header**: Actions (Copy).
- **Metadata Grid**:
    - Type (Text/Image/File) - Badge style.
    - Source Application.
    - Date/Time.
    - Size/Dimensions.
- **Content View**:
    - **Text**: Monospace, syntax highlighting colors (if detected).
        - Keywords: Purple (`#C084FC`)
        - Strings: Green (`#4ADE80`)
        - Functions: Yellow (`#FDE047`)
    - **Image**: Fit to container, rounded corners.
- **Footer**: Edit / Delete buttons.

### 3.5 Buttons
- **Primary (Copy)**: Teal gradient background, White text, Shadow.
- **Secondary (Edit)**: Glass background (`white/8`), White border (`white/10`).
- **Destructive (Delete)**: Red text, Red/20 hover background.

---

## 4. macOS Implementation Guide

### 4.1 Visual Effect Views (AppKit/SwiftUI)

Since the design relies heavily on "Glassmorphism", use native materials:

**SwiftUI:**
```swift
// Base Window Background
.background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))

// Card / Section Background
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
```

**AppKit (`NSVisualEffectView`):**
- Material: `.hudWindow` or `.sidebar` for the deep dark translucent look.
- Blending Mode: `.behindWindow`.

### 4.2 Iconography
Use SF Symbols where possible to match the prototypes:
- Search: `magnifyingglass`
- Copy: `doc.on.doc`
- Edit: `pencil`
- Delete: `trash`
- Arrow Right: `chevron.right`
- Close: `xmark`

### 4.3 Scrollbars
The prototype uses a custom thin scrollbar.
- **macOS Default**: Use standard auto-hiding scrollbars.
- **Custom**: If strictly following design, hide default scrollbars and implement a custom indicator, but **native behavior is preferred**.

---

## 5. Assets & Resources

- **Icons**: SF Symbols 5.0+
- **Colors**: Define in `Assets.xcassets` as named colors (e.g., `AccentColor`, `GlassBackground`).
- **Fonts**: Standard macOS System Fonts.

