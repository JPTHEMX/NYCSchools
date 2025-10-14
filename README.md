import UIKit

@MainActor
class AsyncTextView: UITextView {

    private var currentTask: Task<Void, Never>?
    private var currentTextStyle: UIFont.TextStyle?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        isEditable = false
        isSelectable = true
        isScrollEnabled = true
        dataDetectorTypes = [.link]
        adjustsFontForContentSizeCategory = true
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
    }

    func setAttributedTextAsync(
        text: String?,
        font: UIFont,
        textStyle: UIFont.TextStyle? = nil,
        color: UIColor
    ) {
        currentTask?.cancel()
        
        let finalFont: UIFont
        let effectiveTextStyle: UIFont.TextStyle?
        
        if let textStyle = textStyle {
            effectiveTextStyle = textStyle
            finalFont = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
            currentTextStyle = textStyle
        }
        else if let detectedTextStyle = detectTextStyleFromFont(font) {
            effectiveTextStyle = detectedTextStyle
            finalFont = UIFontMetrics(forTextStyle: detectedTextStyle).scaledFont(for: font)
            currentTextStyle = detectedTextStyle
        }
        else if let storedTextStyle = currentTextStyle {
            effectiveTextStyle = storedTextStyle
            finalFont = UIFontMetrics(forTextStyle: storedTextStyle).scaledFont(for: font)
        }
        else {
            effectiveTextStyle = nil
            finalFont = font
        }

        self.text = text
        self.font = finalFont
        self.textColor = color

        currentTask = Task {
            do {
                guard !Task.isCancelled else {
                    return
                }
                
                guard let text = text else {
                    self.attributedText = NSAttributedString(string: "")
                    return
                }

                var attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: color
                ]
                
                if let effectiveTextStyle = effectiveTextStyle {
                    let scaledFont = UIFontMetrics(forTextStyle: effectiveTextStyle).scaledFont(for: font)
                    attributes[.font] = scaledFont
                } else {
                    attributes[.font] = font
                }
                
                let attributedString = NSAttributedString(string: text, attributes: attributes)
                
                self.attributedText = attributedString
                self.adjustsFontForContentSizeCategory = effectiveTextStyle != nil

            } catch {
                print("Error generating attributed text: \(error)")
            }
        }
    }
    
    private func detectTextStyleFromFont(_ font: UIFont) -> UIFont.TextStyle? {
        let textStyles: [UIFont.TextStyle] = [
            .largeTitle, .title1, .title2, .title3,
            .headline, .subheadline, .body, .callout,
            .footnote, .caption1, .caption2
        ]
        
        for style in textStyles {
            let preferredFont = UIFont.preferredFont(forTextStyle: style)
            
            if preferredFont.fontName == font.fontName &&
               abs(preferredFont.pointSize - font.pointSize) < 1.0 {
                return style
            }
        }
        
        return nil
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory,
           let textStyle = currentTextStyle,
           let currentFont = font {
            
            let scaledFont = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: currentFont)
            self.font = scaledFont
            
            if let attributedText = self.attributedText {
                let mutableAttributedText = NSMutableAttributedString(attributedString: attributedText)
                let range = NSRange(location: 0, length: mutableAttributedText.length)
                mutableAttributedText.addAttribute(.font, value: scaledFont, range: range)
                self.attributedText = mutableAttributedText
            }
        }
    }
}
