import SwiftUI
import UIKit

/// A reusable numeric input field with:
/// - Gray "0" shown when empty/unfocused (pseudo-placeholder that is real text, selectable)
/// - selectAll on focus (first keystroke replaces the zero)
/// - Maximum decimal places enforcement (default 2; use 0 for integers, 4 for exchange rates)
/// - Decimal pad keyboard
/// - When cleared and loses focus, reverts to showing "0"
/// - On save: treat "" as 0.0 (binding stores "" for zero state)
struct CurrencyInputField: View {
    @Binding var text: String
    /// Fixed width. Pass nil to let the field expand (e.g. for blind fields inside HStack).
    var width: CGFloat? = 100
    var textAlignment: TextAlignment = .trailing
    /// 0 = integers only, 2 = currency (default), 4 = exchange rates
    var maxDecimalPlaces: Int = 2
    var textColor: Color = .appPrimary
    /// Allow a leading minus sign (e.g. for adjustment amounts)
    var allowsNegative: Bool = false
    /// Called when focus changes; passes the new isFocused value.
    var onFocusChange: ((Bool) -> Void)? = nil

    @State private var internalText: String = "0"
    @FocusState private var isFocused: Bool

    var isShowingPlaceholder: Bool {
        (internalText == "0" || internalText.isEmpty) && !isFocused
    }

    var body: some View {
        let field = TextField("", text: $internalText)
            .keyboardType(allowsNegative ? .numbersAndPunctuation : .decimalPad)
            .multilineTextAlignment(textAlignment)
            .foregroundColor(isShowingPlaceholder ? Color(hex: "8A8A8A") : textColor)
            .focused($isFocused)
            .onChange(of: internalText) { _, new in
                let filtered = filterInput(new, maxDecimals: maxDecimalPlaces, allowsNegative: allowsNegative)
                if filtered != new {
                    internalText = filtered
                }
                // A lone minus sign is in-progress input — don't sync yet
                if filtered == "-" { return }
                // Sync to binding; empty or pure zero maps to "" externally
                let val = Double(filtered) ?? 0
                text = (filtered.isEmpty || (val == 0 && !filtered.contains("."))) ? "" : filtered
            }
            .onChange(of: isFocused) { _, focused in
                onFocusChange?(focused)
                if focused {
                    // If showing placeholder "0", keep as "0" so selectAll has content to select.
                    // The global .selectAllOnFocus() modifier on the parent Form handles selectAll.
                    if internalText.isEmpty {
                        internalText = "0"
                    }
                } else {
                    // Losing focus: if empty, effectively zero, or lone minus, revert to gray placeholder "0"
                    let val = Double(internalText) ?? 0
                    if internalText.isEmpty || val == 0 || internalText == "-" {
                        internalText = "0"
                        text = ""
                    }
                }
            }
            .onAppear {
                internalText = text.isEmpty ? "0" : text
            }
            .onChange(of: text) { _, newText in
                // Sync internalText from external binding changes when not focused
                if !isFocused {
                    internalText = newText.isEmpty ? "0" : newText
                }
            }

        if let w = width {
            field.frame(width: w)
        } else {
            field
        }
    }

    private func filterInput(_ input: String, maxDecimals: Int, allowsNegative: Bool = false) -> String {
        if input.isEmpty { return "" }

        var working = input
        var isNegative = false

        if allowsNegative && working.hasPrefix("-") {
            isNegative = true
            working = String(working.dropFirst())
            // Lone minus: valid in-progress input
            if working.isEmpty { return "-" }
        }

        // For maxDecimals == 0, only allow digits (no decimal point)
        if maxDecimals == 0 {
            let digits = String(working.filter { $0.isNumber })
            return isNegative && !digits.isEmpty ? "-" + digits : digits
        }

        var result = ""
        var dotSeen = false
        var decimalCount = 0

        for char in working {
            if char.isNumber {
                if dotSeen {
                    if decimalCount < maxDecimals {
                        result.append(char)
                        decimalCount += 1
                    }
                    // else: ignore — enforcing max decimal places
                } else {
                    result.append(char)
                }
            } else if char == "." && !dotSeen {
                dotSeen = true
                result.append(char)
            }
            // Ignore any other character
        }

        return isNegative && !result.isEmpty ? "-" + result : result
    }
}
