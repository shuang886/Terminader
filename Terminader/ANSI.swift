//
//  ANSI.swift
//  Terminader
//
//  Created by Steven Huang on 9/21/23.
//

import SwiftUI

extension AttributedString {
    private enum ANSIParserState {
        case initial, escaped, firstParameter, secondParameter, xtermStuff, vt100Stuff
    }
    
    /// Parses a string that optionally contains certain ANSI escape sequences and emits an attributed string that
    /// translates the sequences to text attributes. This implementation is *rudimentary and very incomplete*.
    ///
    /// - Parameter fromANSI: Input string that may contain ANSI escape sequences.
    /// - Returns: Attributed string interpretation of the input string.
    static func create(fromANSI string: String) -> AttributedString {
        var state = ANSIParserState.initial
        var output = AttributedString("")
        var chars: [Character] = []
        
        let baseFont: Font = .body.monospaced()
        var fgColor: Int?
        var bgColor: Int?
        var bold = false
        var italic = false
        var underline = false
        
        var p1: Int?
        var p2: Int?
        
        let emitCharsWithCurrentStyle = {
            if !chars.isEmpty {
                var attrString = AttributedString(chars)
                
                var font = baseFont
                if bold {
                    font = font.bold()
                }
                if italic {
                    font = font.italic()
                }
                attrString.font = font
                
                if underline {
                    attrString.underlineStyle = .single
                }
                attrString.foregroundColor = Color.create(fromANSI: fgColor)
                attrString.backgroundColor = Color.create(fromANSI: bgColor)
                
                output += attrString
                chars = []
            }
        }
        
        for char in string {
            switch state {
            case .initial:
                if char == "\u{1B}" {
                    emitCharsWithCurrentStyle()
                    p1 = nil
                    p2 = nil
                    state = .escaped
                }
                else {
                    chars.append(char)
                }
            case .escaped:
                switch char {
                case "[": state = .firstParameter
                case "(": state = .vt100Stuff
                default:  state = .initial
                }
            case .firstParameter:
                if char.isNumber {
                    // keep reading digits of the number into p1
                    p1 = (p1 ?? 0) * 10 + (char.wholeNumberValue ?? 0)
                }
                else if char == "?" {
                    state = .xtermStuff
                }
                else if char == "m" || char == ";" {
                    // https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_(Select_Graphic_Rendition)_parameters
                    if p1 == nil {
                        // "CSI m is treated as CSI 0 m"
                        p1 = 0
                    }
                    switch p1! {
                    case 0:
                        bold = false
                        italic = false
                        underline = false
                        italic = false
                        fgColor = nil
                        bgColor = nil
                    case 1:
                        bold = true
                    case 3:
                        italic = true
                    case 4:
                        underline = true
                    case 24:
                        underline = false
                    case 30...37, 90...97:
                        fgColor = p1
                    case 39:
                        fgColor = nil
                    default:
                        break
                    }
                    state = (char == "m") ? .initial : .secondParameter
                }
                else if char == "J" {
                    if let p1, p1 == 2 {
                        // "clear screen"
                        output = AttributedString("")
                    }
                    state = .initial
                }
                else {
                    state = .initial
                }
            case .secondParameter:
                if char.isNumber {
                    // keep reading digits of the number into p2
                    p2 = (p2 ?? 0) * 10 + (char.wholeNumberValue ?? 0)
                }
                else if char == "m" {
                    switch p2! {
                    case 40...47, 100...107:
                        bgColor = p2
                    case 49:
                        bgColor = nil
                    default:
                        break
                    }
                    state = .initial
                }
                else {
                    state = .initial
                }
            case .xtermStuff:
                // https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Functions-using-CSI-_-ordered-by-the-final-character_s_
                if char == "h" {
                    state = .initial
                }
            case .vt100Stuff:
                // https://espterm.github.io/docs/VT100%20escape%20codes.html
                if ["A", "B", "0", "1", "2"].contains(char) {
                    state = .initial
                }
            }
        }
        emitCharsWithCurrentStyle()
        return output
    }
}

extension Color {
    /// Emit a Color from an ANSI SGR (Select Graphic Rendition) parameter
    ///
    /// - Parameter fromANSI: SGR code as defined in https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_(Select_Graphic_Rendition)_parameters
    /// - Returns: Color
    static func create(fromANSI: Int?) -> Color? {
        guard let fromANSI else { return nil }
        switch fromANSI {
        case 39:      return Color(NSColor.textColor)
        case 49:      return Color(NSColor.textBackgroundColor)
        case 30, 40:  return .ansiBlack
        case 31, 41:  return .ansiRed
        case 32, 42:  return .ansiGreen
        case 33, 43:  return .ansiYellow
        case 34, 44:  return .ansiBlue
        case 35, 45:  return .ansiMagenta
        case 36, 46:  return .ansiCyan
        case 37, 47:  return .ansiWhite
        case 90, 100: return .ansiBrightBlack
        case 91, 101: return .ansiBrightRed
        case 92, 102: return .ansiBrightGreen
        case 93, 103: return .ansiBrightYellow
        case 94, 104: return .ansiBrightBlue
        case 95, 105: return .ansiBrightMagenta
        case 96, 106: return .ansiBrightCyan
        case 97, 107: return .ansiBrightWhite
        default: return nil
        }
    }
}
