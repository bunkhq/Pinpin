import AppKit
import SwiftUI

/// Pinpin's own pin glyphs, replacing the SF Symbols `pin`, `pin.fill` and `pin.slash`.
/// The SVG sources live in `assets/pin-filled.svg`, `assets/pin-outline.svg` and `assets/pin-remove.svg`; they're embedded here so
/// the binary needs no resource bundle. The images are templates, so they take the menu bar's or the
/// SwiftUI view's foreground color like a symbol would.
enum PinIcon {
    static let filled = image(svg: """
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M15.63 1.97011C13.2 1.74011 10.8 1.74011 8.37 1.97011C6.79 2.12011 5.71 3.63011 6.09 5.17011L7.07 9.26011C7.11 9.40011 7.09 9.50011 7.04 9.60011C6.98 9.71011 6.86 9.84011 6.68 9.96011C5.02 10.9601 4 12.7601 4 14.7001C4 15.4501 4.55 16.0801 5.29 16.1901C7.18 16.4601 9.08 16.6301 11 16.6801V21.0001C11 21.5501 11.45 22.0001 12 22.0001C12.55 22.0001 13 21.5501 13 21.0001V16.6801C14.92 16.6301 16.82 16.4601 18.71 16.1901C19.45 16.0801 20 15.4501 20 14.7001C20 12.7601 18.98 10.9601 17.32 9.96011C17.14 9.84011 17.02 9.71011 16.96 9.60011C16.91 9.50011 16.89 9.40011 16.93 9.26011L17.91 5.17011C18.29 3.63011 17.21 2.12011 15.63 1.97011Z" fill="black"/>
    </svg>
    """)

    static let outline = image(svg: """
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M7.06 4.93011C6.83 3.98011 7.49 3.06011 8.46 2.97011C10.83 2.74011 13.17 2.74011 15.54 2.97011C16.51 3.06011 17.17 3.98011 16.94 4.93011L15.96 9.02011C15.77 9.78011 16.18 10.4301 16.81 10.8101C18.17 11.6301 19 13.1101 19 14.7001C19 14.9501 18.82 15.1601 18.57 15.2001C16.39 15.5101 14.2 15.6901 12 15.6901C9.8 15.6901 7.61 15.5101 5.43 15.2001C5.18 15.1601 5 14.9501 5 14.7001C5 13.1101 5.83 11.6301 7.19 10.8101C7.82 10.4301 8.23 9.78011 8.04 9.02011L7.06 4.93011Z" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" stroke="black"/>
    <path d="M12 20.9999V15.6899" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" stroke="black"/>
    </svg>
    """)

    static let remove = image(svg: """
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M8.6377 7.22363L9.0127 8.78711C9.33548 10.0977 8.5824 11.1384 7.70605 11.667C6.77177 12.2305 6.15678 13.1971 6.02637 14.2715C8.01596 14.5372 10.0065 14.6904 12 14.6904C13.3065 14.6904 14.6115 14.6222 15.916 14.502L17.7324 16.3184C15.8346 16.5538 13.9235 16.6904 12 16.6904C9.74559 16.6904 7.50782 16.5059 5.28906 16.1904C5.28352 16.1896 5.27799 16.1884 5.27246 16.1875C4.5439 16.0709 4.00019 15.4478 4 14.7002C4.00005 12.7626 5.01145 10.9565 6.67383 9.9541C6.86022 9.84163 6.9763 9.71055 7.03418 9.59863C7.08493 9.50018 7.10355 9.39598 7.07031 9.2627L7.06738 9.25293L6.08789 5.16504C6.04198 4.97522 6.01748 4.78568 6.01367 4.59961L8.6377 7.22363ZM8.36328 1.97559C10.7975 1.73935 13.2025 1.73837 15.6367 1.97461L15.6357 1.97559C17.21 2.12369 18.2856 3.6234 17.9121 5.16602L17.9111 5.16504L16.9326 9.25293L16.9307 9.2627C16.8974 9.39598 16.9151 9.50018 16.9658 9.59863C17.0237 9.71055 17.1398 9.84163 17.3262 9.9541C18.9885 10.9565 19.9999 12.7626 20 14.7002C19.9999 15.0008 19.9103 15.2802 19.7578 15.5156L17.8135 13.5713C17.5508 12.7857 17.0196 12.1047 16.2939 11.667C15.4177 11.1384 14.6647 10.0976 14.9873 8.78711L15.9678 4.69727V4.69531C16.054 4.33907 15.8111 3.9996 15.4473 3.96582H15.4434C13.1376 3.74206 10.8624 3.74206 8.55664 3.96582H8.55273C8.45671 3.97474 8.3703 4.00657 8.29492 4.05273L6.87012 2.62793C7.26762 2.26976 7.78137 2.03054 8.36328 1.97559Z" fill="black"/>
    <path d="M12 20.9999V15.6899" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" stroke="black"/>
    <path d="M3.29289 3.29289C3.68342 2.90237 4.31643 2.90237 4.70696 3.29289L20.707 19.2929C21.0975 19.6834 21.0975 20.3164 20.707 20.707C20.3164 21.0975 19.6834 21.0975 19.2929 20.707L3.29289 4.70696C2.90237 4.31643 2.90237 3.68342 3.29289 3.29289Z" fill="black"/>
    </svg>
    """)

    private static func image(svg: String) -> NSImage {
        let image = NSImage(data: Data(svg.utf8)) ?? NSImage()
        image.isTemplate = true
        return image
    }
}

/// A pin glyph sized to sit beside text, tinted by `foregroundStyle` like an SF Symbol.
struct PinGlyph: View {
    var image = PinIcon.filled
    var size: CGFloat

    var body: some View {
        Image(nsImage: image)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
