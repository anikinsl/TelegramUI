import Foundation
import SwiftSignalKit
import UIKit
import AsyncDisplayKit
import Display

private func generateLoupeIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Loupe"), color: color)
}

private func generateClearIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: color)
}

private func generateBackground(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    let diameter: CGFloat = 14.0
    return generateImage(CGSize(width: diameter, height: diameter), contextGenerator: { size, context in
        context.setFillColor(backgroundColor.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(foregroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    }, opaque: true)?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
}

private class SearchBarTextField: UITextField {
    public var didDeleteBackwardWhileEmpty: (() -> Void)?
    
    let placeholderLabel: ASTextNode
    var placeholderString: NSAttributedString? {
        didSet {
            self.placeholderLabel.attributedText = self.placeholderString
        }
    }
    
    let prefixLabel: ASTextNode
    var prefixString: NSAttributedString? {
        didSet {
            self.prefixLabel.attributedText = self.prefixString
        }
    }
    
    override init(frame: CGRect) {
        self.placeholderLabel = ASTextNode()
        self.placeholderLabel.isLayerBacked = true
        self.placeholderLabel.displaysAsynchronously = false
        self.placeholderLabel.maximumNumberOfLines = 1
        self.placeholderLabel.truncationMode = .byTruncatingTail
        
        self.prefixLabel = ASTextNode()
        self.prefixLabel.isLayerBacked = true
        self.prefixLabel.displaysAsynchronously = false
        
        super.init(frame: frame)
        
        self.addSubnode(self.placeholderLabel)
        self.addSubnode(self.prefixLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        if bounds.size.width.isZero {
            return CGRect(origin: CGPoint(), size: CGSize())
        }
        var rect = bounds.insetBy(dx: 4.0, dy: 4.0)
        
        let prefixSize = self.prefixLabel.measure(bounds.size)
        if !prefixSize.width.isZero {
            let prefixOffset = prefixSize.width
            rect.origin.x += prefixOffset
            rect.size.width -= prefixOffset
        }
        return rect
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return self.textRect(forBounds: bounds)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let bounds = self.bounds
        if bounds.size.width.isZero {
            return
        }
        
        let constrainedSize = self.textRect(forBounds: self.bounds).size
        let labelSize = self.placeholderLabel.measure(constrainedSize)
        self.placeholderLabel.frame = CGRect(origin: CGPoint(x: self.textRect(forBounds: bounds).minX, y: self.textRect(forBounds: bounds).minY + 1.0), size: labelSize)
        
        let prefixSize = self.prefixLabel.measure(constrainedSize)
        let prefixBounds = bounds.insetBy(dx: 4.0, dy: 4.0)
        self.prefixLabel.frame = CGRect(origin: CGPoint(x: prefixBounds.minX, y: prefixBounds.minY + 1.0), size: prefixSize)
    }
    
    override func deleteBackward() {
        if self.text == nil || self.text!.isEmpty {
            self.didDeleteBackwardWhileEmpty?()
        }
        super.deleteBackward()
    }
}

final class SearchBarNodeTheme {
    let background: UIColor
    let separator: UIColor
    let inputFill: UIColor
    let placeholder: UIColor
    let primaryText: UIColor
    let inputIcon: UIColor
    let inputClear: UIColor
    let accent: UIColor
    let keyboard: PresentationThemeKeyboardColor
    
    init(background: UIColor, separator: UIColor, inputFill: UIColor, primaryText: UIColor, placeholder: UIColor, inputIcon: UIColor, inputClear: UIColor, accent: UIColor, keyboard: PresentationThemeKeyboardColor) {
        self.background = background
        self.separator = separator
        self.inputFill = inputFill
        self.primaryText = primaryText
        self.placeholder = placeholder
        self.inputIcon = inputIcon
        self.inputClear = inputClear
        self.accent = accent
        self.keyboard = keyboard
    }
    
    init(theme: PresentationTheme) {
        self.background = theme.rootController.activeNavigationSearchBar.backgroundColor
        self.separator = theme.rootController.navigationBar.separatorColor
        self.inputFill = theme.rootController.activeNavigationSearchBar.inputFillColor
        self.placeholder = theme.rootController.activeNavigationSearchBar.inputPlaceholderTextColor
        self.primaryText = theme.rootController.activeNavigationSearchBar.inputTextColor
        self.inputIcon = theme.rootController.activeNavigationSearchBar.inputIconColor
        self.inputClear = theme.rootController.activeNavigationSearchBar.inputClearButtonColor
        self.accent = theme.rootController.activeNavigationSearchBar.accentColor
        self.keyboard = theme.chatList.searchBarKeyboardColor
    }
}

class SearchBarNode: ASDisplayNode, UITextFieldDelegate {
    var cancel: (() -> Void)?
    var textUpdated: ((String) -> Void)?
    var clearPrefix: (() -> Void)?
    
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let textBackgroundNode: ASImageNode
    private var activityIndicator: ActivityIndicator?
    private let iconNode: ASImageNode
    private let textField: SearchBarTextField
    private let clearButton: HighlightableButtonNode
    private let cancelButton: HighlightableButtonNode
    
    var placeholderString: NSAttributedString? {
        get {
            return self.textField.placeholderString
        } set(value) {
            self.textField.placeholderString = value
        }
    }
    
    var prefixString: NSAttributedString? {
        get {
            return self.textField.prefixString
        } set(value) {
            let previous = self.prefixString
            let updated: Bool
            if let previous = previous, let value = value {
                updated = !previous.isEqual(to: value)
            } else {
                updated = (previous != nil) != (value != nil)
            }
            if updated {
                self.textField.prefixString = value
                self.textField.setNeedsLayout()
                self.updateIsEmpty()
            }
        }
    }
    
    var text: String {
        get {
            return self.textField.text ?? ""
        } set(value) {
            if self.textField.text ?? "" != value {
                self.textField.text = value
                self.textFieldDidChange(self.textField)
            }
        }
    }
    
    var activity: Bool = false {
        didSet {
            if self.activity != oldValue {
                if self.activity {
                    if self.activityIndicator == nil {
                        let activityIndicator = ActivityIndicator(type: .custom(self.theme.inputIcon, 13.0, 1.0, false))
                        self.activityIndicator = activityIndicator
                        self.addSubnode(activityIndicator)
                        if let (boundingSize, leftInset, rightInset) = self.validLayout {
                            self.updateLayout(boundingSize: boundingSize, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
                        }
                    }
                } else if let activityIndicator = self.activityIndicator {
                    self.activityIndicator = nil
                    activityIndicator.removeFromSupernode()
                }
                self.iconNode.isHidden = self.activity
            }
        }
    }
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    private var theme: SearchBarNodeTheme
    private var strings: PresentationStrings
    
    init(theme: SearchBarNodeTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = theme.background
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = theme.separator
        
        self.textBackgroundNode = ASImageNode()
        self.textBackgroundNode.isLayerBacked = false
        self.textBackgroundNode.displaysAsynchronously = false
        self.textBackgroundNode.displayWithoutProcessing = true
        self.textBackgroundNode.image = generateBackground(backgroundColor: theme.background, foregroundColor: theme.inputFill)
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.image = generateLoupeIcon(color: theme.inputIcon)
        
        self.textField = SearchBarTextField()
        self.textField.autocorrectionType = .no
        self.textField.returnKeyType = .done
        self.textField.font = Font.regular(14.0)
        self.textField.textColor = theme.primaryText
        
        self.clearButton = HighlightableButtonNode()
        self.clearButton.imageNode.displaysAsynchronously = false
        self.clearButton.imageNode.displayWithoutProcessing = true
        self.clearButton.displaysAsynchronously = false
        self.clearButton.setImage(generateClearIcon(color: theme.inputClear), for: [])
        self.clearButton.isHidden = true
        
        switch theme.keyboard {
            case .light:
                self.textField.keyboardAppearance = .default
            case .dark:
                self.textField.keyboardAppearance = .dark
        }
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.cancelButton.setAttributedTitle(NSAttributedString(string: strings.Common_Cancel, font: Font.regular(17.0), textColor: theme.accent), for: [])
        self.cancelButton.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.textBackgroundNode)
        self.view.addSubview(self.textField)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.clearButton)
        self.addSubnode(self.cancelButton)
        
        self.textField.delegate = self
        self.textField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
        
        self.textField.didDeleteBackwardWhileEmpty = { [weak self] in
            self?.clearPressed()
        }
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.clearButton.addTarget(self, action: #selector(self.clearPressed), forControlEvents: .touchUpInside)
    }
    
    func updateThemeAndStrings(theme: SearchBarNodeTheme, strings: PresentationStrings) {
        if self.theme !== theme {
            self.cancelButton.setAttributedTitle(NSAttributedString(string: strings.Common_Cancel, font: Font.regular(17.0), textColor: theme.accent), for: [])
            self.backgroundNode.backgroundColor = theme.background
            self.separatorNode.backgroundColor = theme.separator
            self.textBackgroundNode.image = generateBackground(backgroundColor: theme.background, foregroundColor: theme.inputFill)
            
        }
        
        self.theme = theme
        self.strings = strings
        if let (boundingSize, leftInset, rightInset) = self.validLayout {
            self.updateLayout(boundingSize: boundingSize, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
        }
    }
    
    func updateLayout(boundingSize: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (boundingSize, leftInset, rightInset)
        
        self.backgroundNode.frame = self.bounds
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: self.bounds.size.height), size: CGSize(width: self.bounds.size.width, height: UIScreenPixel)))
        
        let verticalOffset: CGFloat = boundingSize.height - 64.0
        
        let contentFrame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: boundingSize.width - leftInset - rightInset, height: boundingSize.height))
        
        let cancelButtonSize = self.cancelButton.measure(CGSize(width: 100.0, height: CGFloat.infinity))
        transition.updateFrame(node: self.cancelButton, frame: CGRect(origin: CGPoint(x: contentFrame.maxX - 8.0 - cancelButtonSize.width, y: verticalOffset + 31.0), size: cancelButtonSize))
        
        let textBackgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX + 8.0, y: verticalOffset + 28.0), size: CGSize(width: contentFrame.width - 16.0 - cancelButtonSize.width - 11.0, height: 28.0))
        transition.updateFrame(node: self.textBackgroundNode, frame: textBackgroundFrame)
        
        let textFrame = CGRect(origin: CGPoint(x: textBackgroundFrame.minX + 23.0, y: textBackgroundFrame.minY), size: CGSize(width: max(1.0, textBackgroundFrame.size.width - 23.0 - 20.0), height: textBackgroundFrame.size.height))
        
        if let iconImage = self.iconNode.image {
            let iconSize = iconImage.size
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: textBackgroundFrame.minX + 8.0, y: textBackgroundFrame.minY + floor((textBackgroundFrame.size.height - iconSize.height) / 2.0)), size: iconSize))
        }
        
        if let activityIndicator = self.activityIndicator {
            let indicatorSize = activityIndicator.measure(CGSize(width: 32.0, height: 32.0))
            transition.updateFrame(node: activityIndicator, frame: CGRect(origin: CGPoint(x: textBackgroundFrame.minX + 7.0, y: textBackgroundFrame.minY + floor((textBackgroundFrame.size.height - indicatorSize.height) / 2.0)), size: indicatorSize))
        }
        
        let clearSize = self.clearButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.clearButton, frame: CGRect(origin: CGPoint(x: textBackgroundFrame.maxX - 8.0 - clearSize.width, y: textBackgroundFrame.minY + floor((textBackgroundFrame.size.height - clearSize.height) / 2.0)), size: clearSize))
        
        self.textField.frame = textFrame
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let cancel = self.cancel {
                cancel()
            }
        }
    }
    
    func activate() {
        self.textField.becomeFirstResponder()
    }
    
    func animateIn(from node: SearchBarPlaceholderNode, duration: Double, timingFunction: String) {
        let initialTextBackgroundFrame = node.convert(node.backgroundNode.frame, to: self)
        
        let initialBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.size.width, height: max(0.0, initialTextBackgroundFrame.maxY + 8.0)))
        if let fromBackgroundColor = node.backgroundColor, let toBackgroundColor = self.backgroundNode.backgroundColor {
            self.backgroundNode.layer.animate(from: fromBackgroundColor.cgColor, to: toBackgroundColor.cgColor, keyPath: "backgroundColor", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: duration * 0.7)
        } else {
            self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        }
        self.backgroundNode.layer.animateFrame(from: initialBackgroundFrame, to: self.backgroundNode.frame, duration: duration, timingFunction: timingFunction)
        
        let initialSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: max(0.0, initialTextBackgroundFrame.maxY + 8.0)), size: CGSize(width: self.bounds.size.width, height: UIScreenPixel))
        self.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        self.separatorNode.layer.animateFrame(from: initialSeparatorFrame, to: self.separatorNode.frame, duration: duration, timingFunction: timingFunction)
        
        self.textBackgroundNode.layer.animateFrame(from: initialTextBackgroundFrame, to: self.textBackgroundNode.frame, duration: duration, timingFunction: timingFunction)
        
        let textFieldFrame = self.textField.frame
        let initialLabelNodeFrame = CGRect(origin: node.labelNode.frame.offsetBy(dx: initialTextBackgroundFrame.origin.x - 4.0, dy: initialTextBackgroundFrame.origin.y - 6.0).origin, size: textFieldFrame.size)
        self.textField.layer.animateFrame(from: initialLabelNodeFrame, to: self.textField.frame, duration: duration, timingFunction: timingFunction)
        
        let iconFrame = self.iconNode.frame
        let initialIconFrame = CGRect(origin: node.iconNode.frame.offsetBy(dx: initialTextBackgroundFrame.origin.x, dy: initialTextBackgroundFrame.origin.y).origin, size: iconFrame.size)
        self.iconNode.layer.animateFrame(from: initialIconFrame, to: self.iconNode.frame, duration: duration, timingFunction: timingFunction)
        
        let cancelButtonFrame = self.cancelButton.frame
        self.cancelButton.layer.animatePosition(from: CGPoint(x: self.bounds.size.width + cancelButtonFrame.size.width / 2.0, y: initialTextBackgroundFrame.minY + 2.0 + cancelButtonFrame.size.height / 2.0), to: self.cancelButton.layer.position, duration: duration, timingFunction: timingFunction)
        node.isHidden = true
    }
    
    func deactivate(clear: Bool = true) {
        self.textField.resignFirstResponder()
        if clear {
            self.textField.text = nil
            self.textField.placeholderLabel.isHidden = false
        }
    }
    
    func transitionOut(to node: SearchBarPlaceholderNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        let targetTextBackgroundFrame = node.convert(node.backgroundNode.frame, to: self)
        
        let duration: Double = 0.5
        let timingFunction = kCAMediaTimingFunctionSpring
        
        node.isHidden = true
        self.clearButton.isHidden = true
        self.textField.text = ""
        
        var backgroundCompleted = false
        var separatorCompleted = false
        var textBackgroundCompleted = false
        let intermediateCompletion: () -> Void = { [weak node] in
            if backgroundCompleted && separatorCompleted && textBackgroundCompleted {
                completion()
                node?.isHidden = false
            }
        }
        
        let targetBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.size.width, height: max(0.0, targetTextBackgroundFrame.maxY + 8.0)))
        if let toBackgroundColor = node.backgroundColor, let fromBackgroundColor = self.backgroundNode.backgroundColor {
            self.backgroundNode.layer.animate(from: fromBackgroundColor.cgColor, to: toBackgroundColor.cgColor, keyPath: "backgroundColor", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: duration * 0.5, removeOnCompletion: false)
        } else {
            self.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration / 2.0, removeOnCompletion: false)
        }
        self.backgroundNode.layer.animateFrame(from: self.backgroundNode.frame, to: targetBackgroundFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { _ in
            backgroundCompleted = true
            intermediateCompletion()
        })
        
        let targetSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: max(0.0, targetTextBackgroundFrame.maxY + 8.0)), size: CGSize(width: self.bounds.size.width, height: UIScreenPixel))
        self.separatorNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration / 2.0, removeOnCompletion: false)
        self.separatorNode.layer.animateFrame(from: self.separatorNode.frame, to: targetSeparatorFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { _ in
            separatorCompleted = true
            intermediateCompletion()
        })
        
        self.textBackgroundNode.layer.animateFrame(from: self.textBackgroundNode.frame, to: targetTextBackgroundFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { _ in
            textBackgroundCompleted = true
            intermediateCompletion()
        })
        
        let transitionBackgroundNode = ASImageNode()
        transitionBackgroundNode.isLayerBacked = true
        transitionBackgroundNode.displaysAsynchronously = false
        transitionBackgroundNode.displayWithoutProcessing = true
        transitionBackgroundNode.image = node.backgroundNode.image
        self.insertSubnode(transitionBackgroundNode, aboveSubnode: self.textBackgroundNode)
        transitionBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration / 2.0, removeOnCompletion: false)
        transitionBackgroundNode.layer.animateFrame(from: self.textBackgroundNode.frame, to: targetTextBackgroundFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        
        let textFieldFrame = self.textField.frame
        let targetLabelNodeFrame = CGRect(origin: CGPoint(x: node.labelNode.frame.minX + targetTextBackgroundFrame.origin.x - 4.0, y: targetTextBackgroundFrame.minY + floorToScreenPixels((targetTextBackgroundFrame.size.height - textFieldFrame.size.height) / 2.0)), size: textFieldFrame.size)
        self.textField.layer.animateFrame(from: self.textField.frame, to: targetLabelNodeFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        if let snapshot = node.labelNode.layer.snapshotContentTree() {
            snapshot.frame = CGRect(origin: self.textField.placeholderLabel.frame.origin.offsetBy(dx: 0.0, dy: UIScreenPixel), size: node.labelNode.frame.size)
            self.textField.layer.addSublayer(snapshot)
            snapshot.animateAlpha(from: 0.0, to: 1.0, duration: duration * 2.0 / 3.0, timingFunction: kCAMediaTimingFunctionLinear)
            self.textField.placeholderLabel.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 3.0 / 2.0, timingFunction: kCAMediaTimingFunctionLinear, removeOnCompletion: false)
            
        }
        
        let iconFrame = self.iconNode.frame
        let targetIconFrame = CGRect(origin: node.iconNode.frame.offsetBy(dx: targetTextBackgroundFrame.origin.x, dy: targetTextBackgroundFrame.origin.y).origin, size: iconFrame.size)
        self.iconNode.image = node.iconNode.image
        self.iconNode.layer.animateFrame(from: self.iconNode.frame, to: targetIconFrame, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        
        let cancelButtonFrame = self.cancelButton.frame
        self.cancelButton.layer.animatePosition(from: self.cancelButton.layer.position, to: CGPoint(x: self.bounds.size.width + cancelButtonFrame.size.width / 2.0, y: targetTextBackgroundFrame.minY + 2.0 + cancelButtonFrame.size.height / 2.0), duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.range(of: "\n") != nil {
            return false
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.textField.resignFirstResponder()
        return false
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        self.updateIsEmpty()
        if let textUpdated = self.textUpdated {
            textUpdated(textField.text ?? "")
        }
    }
    
    private func updateIsEmpty() {
        let isEmpty = !(textField.text?.isEmpty ?? true)
        if isEmpty != self.textField.placeholderLabel.isHidden {
            self.textField.placeholderLabel.isHidden = isEmpty
        }
        self.clearButton.isHidden = !isEmpty && self.prefixString == nil
    }
    
    @objc func cancelPressed() {
        if let cancel = self.cancel {
            cancel()
        }
    }
    
    @objc func clearPressed() {
        if (self.textField.text?.isEmpty ?? true) {
            if self.prefixString != nil {
                self.clearPrefix?()
            }
        } else {
            self.textField.text = ""
            self.textFieldDidChange(self.textField)
        }
    }
}
