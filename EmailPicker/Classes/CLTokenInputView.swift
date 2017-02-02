//
//  CLTokenInputView.swift
//  CLTokenInputView
//
//  Created by Robert La Ferla on 1/13/16 from original ObjC version by Rizwan Sattar.
//  Copyright © 2016 Robert La Ferla. All rights reserved.
//

import Foundation
import UIKit

protocol CLTokenInputViewDelegate: class {
    func tokenInputViewDidEndEditing(aView: CLTokenInputView)
    func tokenInputViewDidBeginEditing(aView: CLTokenInputView)
    func tokenInputView(aView:CLTokenInputView, didChangeText text:String)
    func tokenInputView(aView:CLTokenInputView, didAddToken token:CLToken)
    func tokenInputView(aView:CLTokenInputView, didRemoveToken token:CLToken)
    func tokenInputView(aView:CLTokenInputView, tokenForText text:String) -> CLToken?
    func tokenInputView(aView:CLTokenInputView, didChangeHeightTo height:CGFloat)
    func tokenInputViewFont(for aView:CLTokenInputView) -> UIFont
}

class CLTokenInputView: UIView, CLBackspaceDetectingTextFieldDelegate, CLTokenViewDelegate {
    weak var delegate:CLTokenInputViewDelegate?
    var fieldLabel:UILabel!
    var fieldView:UIView? {
        willSet {
            if self.fieldView != newValue {
                self.fieldView?.removeFromSuperview()
            }
        }
        
        didSet {
            if oldValue != self.fieldView {
                if (self.fieldView != nil) {
                    self.addSubview(self.fieldView!)
                }
                self.repositionViews()
            }
        }
    }
    var fieldName:String? {
        didSet {
            if oldValue != self.fieldName {
                self.fieldLabel.text = self.fieldName
                self.fieldLabel.sizeToFit()
                let showField:Bool = self.fieldName!.characters.count > 0
                self.fieldLabel.isHidden = !showField
                if showField && self.fieldLabel.superview == nil {
                    self.addSubview(self.fieldLabel)
                }
                else if !showField && self.fieldLabel.superview != nil {
                    self.fieldLabel.removeFromSuperview()
                }
                
                if oldValue == nil || oldValue != self.fieldName {
                    self.repositionViews()
                }
            }
            
        }
    }
    var fieldColor:UIColor? {
        didSet {
            self.fieldLabel.textColor = self.fieldColor
        }
    }
    var placeholderText:String? {
        didSet {
            if oldValue != self.placeholderText {
                self.updatePlaceholderTextVisibility()
            }
        }
    }
    var accessoryView:UIView? {
        willSet {
            if self.accessoryView != newValue {
                self.accessoryView?.removeFromSuperview()
            }
        }
        
        didSet {
            if oldValue != self.accessoryView {
                if (self.accessoryView != nil) {
                    self.addSubview(self.accessoryView!)
                }
                self.repositionViews()
            }
        }
    }
    var keyboardType: UIKeyboardType! {
        didSet {
            self.textField.keyboardType = self.keyboardType;
        }
    }
    var autocapitalizationType: UITextAutocapitalizationType! {
        didSet {
            self.textField.autocapitalizationType = self.autocapitalizationType;
        }
    }
    var autocorrectionType: UITextAutocorrectionType! {
        didSet {
            self.textField.autocorrectionType = self.autocorrectionType;
        }
    }
    var tokenizationCharacters:Set<String> = Set<String>()
    var drawBottomBorder:Bool! {
        didSet {
            if oldValue != self.drawBottomBorder {
                self.setNeedsDisplay()
            }
        }
    }
    //var editing:Bool = false
    
    var tokens:[CLToken] = []
    var tokenViews:[CLTokenView] = []
    var textField:CLBackspaceDetectingTextField!
    var intrinsicContentHeight:CGFloat!
    var additionalTextFieldYOffset:CGFloat!
    
    let HSPACE:CGFloat = 0.0
    let TEXT_FIELD_HSPACE:CGFloat = 4.0 // Note: Same as CLTokenView.PADDING_X
    let VSPACE:CGFloat = 4.0
    let MINIMUM_TEXTFIELD_WIDTH:CGFloat = 56.0
    let PADDING_TOP:CGFloat = 10.0
    let PADDING_BOTTOM:CGFloat = 10.0
    let PADDING_LEFT:CGFloat = 8.0
    let PADDING_RIGHT:CGFloat = 16.0
    let STANDARD_ROW_HEIGHT:CGFloat = 25.0
    let FIELD_MARGIN_X:CGFloat = 4.0
    
    func commonInit() {
        self.textField = CLBackspaceDetectingTextField(frame: self.bounds)
        self.textField.translatesAutoresizingMaskIntoConstraints = false
        self.textField.backgroundColor = UIColor.clear
        self.textField.keyboardType = .emailAddress
        self.textField.autocorrectionType = .no
        self.textField.autocapitalizationType = .none
        self.textField.myDelegate = self
        self.textField.font = delegate?.tokenInputViewFont(for: self)
        //self.additionalTextFieldYOffset = 0.0
        self.additionalTextFieldYOffset = 1.5
        self.textField.addTarget(self, action: #selector(CLTokenInputView.onTextFieldDidChange(sender:)), for: .editingChanged)
        self.addSubview(self.textField)
        
        self.fieldLabel = UILabel(frame: CGRect.zero)
        self.fieldLabel.translatesAutoresizingMaskIntoConstraints = false
        self.fieldLabel.font = delegate?.tokenInputViewFont(for: self)
        self.fieldLabel.textColor = self.fieldColor
        self.addSubview(self.fieldLabel)
        self.fieldLabel.isHidden = true
        
        self.fieldColor = UIColor.lightGray

        self.intrinsicContentHeight = STANDARD_ROW_HEIGHT
        self.repositionViews()
    }
    
    init(delegate: CLTokenInputViewDelegate) {
        super.init(frame: CGRect.zero)
        self.delegate = delegate
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    override var intrinsicContentSize: CGSize {
        get {
            return CGSize(width: UIViewNoIntrinsicMetric, height: max(45, self.intrinsicContentHeight))
        }
    }
    
    override func tintColorDidChange() {
        self.textField.textColor = self.tintColor
        self.tokenViews.forEach { $0.tintColor = self.tintColor }
    }
    
    func addToken(token:CLToken) {
        if self.tokens.contains(token) {
            return
        }
        
        self.tokens.append(token)
        
        let tokenView:CLTokenView = CLTokenView(token: token, font: delegate?.tokenInputViewFont(for: self))
        tokenView.translatesAutoresizingMaskIntoConstraints = false
        tokenView.tintColor = self.tintColor
        tokenView.delegate = self
        
        let intrinsicSize:CGSize = tokenView.intrinsicContentSize
        tokenView.frame = CGRect(x: 0.0, y: 0.0, width: intrinsicSize.width, height: intrinsicSize.height)
        self.tokenViews.append(tokenView)
        self.addSubview(tokenView)
        self.textField.text = ""
        self.delegate?.tokenInputView(aView: self, didAddToken: token)
        self.onTextFieldDidChange(sender: self.textField)
        
        self.updatePlaceholderTextVisibility()
        self.repositionViews()
        
    }
    
    func removeTokenAtIndex(index:Int) {
        if index == -1 {
            return
        }
        let tokenView = self.tokenViews[index]
        tokenView.removeFromSuperview()
        self.tokenViews.remove(at: index)
        let removedToken = self.tokens[index]
        self.tokens.remove(at: index)
        self.delegate?.tokenInputView(aView: self, didRemoveToken: removedToken)
        self.updatePlaceholderTextVisibility()
        self.repositionViews()
    }
    
    func removeToken(token:CLToken) {
        let index:Int? = self.tokens.index(of: token)
        if index != nil {
            self.removeTokenAtIndex(index: index!)
        }
    }
    
    func allTokens() -> [CLToken] {
        return Array(self.tokens)
    }
    
    func tokenizeTextfieldText() -> CLToken? {
        //print("tokenizeTextfieldText()")
        var token:CLToken? = nil
        
        let text:String = self.textField.text!
        if text.characters.count > 0  {
            token = self.delegate?.tokenInputView(aView: self, tokenForText: text)
            if (token != nil) {
                self.addToken(token: token!)
                self.textField.text = ""
                self.onTextFieldDidChange(sender: self.textField)
            }
        }
        
        return token
    }
    
    func repositionViews() {
        let bounds:CGRect = self.bounds
        let rightBoundary:CGFloat = bounds.width - PADDING_RIGHT
        var firstLineRightBoundary:CGFloat = rightBoundary
        var curX:CGFloat = PADDING_LEFT
        var curY:CGFloat = PADDING_TOP
        var totalHeight:CGFloat = STANDARD_ROW_HEIGHT
        var isOnFirstLine:Bool = true
        
        
       // print("repositionViews curX=\(curX) curY=\(curY)")
        
        //print("self.frame=\(self.frame)")

        // Position field view (if set)
        if self.fieldView != nil {
            var fieldViewRect:CGRect = self.fieldView!.frame
            fieldViewRect.origin.x = curX + FIELD_MARGIN_X
            fieldViewRect.origin.y = curY + ((STANDARD_ROW_HEIGHT - fieldViewRect.height / 2.0)) - PADDING_TOP
            self.fieldView?.frame = fieldViewRect
            
            curX = fieldViewRect.maxX + FIELD_MARGIN_X
           // print("fieldViewRect=\(fieldViewRect)")
        }
        
        // Position field label (if field name is set)
        if !(self.fieldLabel.isHidden) {
            var fieldLabelRect:CGRect = self.fieldLabel.frame
            fieldLabelRect.origin.x = curX + FIELD_MARGIN_X
            fieldLabelRect.origin.y = curY + ((STANDARD_ROW_HEIGHT - fieldLabelRect.height / 2.0)) - PADDING_TOP

            self.fieldLabel.frame = fieldLabelRect
            
            curX = fieldLabelRect.maxX + FIELD_MARGIN_X
            //print("fieldLabelRect=\(fieldLabelRect)")
        }

        // Position accessory view (if set)
        if self.accessoryView != nil {
            var accessoryRect:CGRect = self.accessoryView!.frame;
            accessoryRect.origin.x = bounds.width - PADDING_RIGHT - accessoryRect.width
            accessoryRect.origin.y = curY;
            self.accessoryView!.frame = accessoryRect;
            
            firstLineRightBoundary = accessoryRect.minX - HSPACE;
        }

        // Position token views
        var tokenRect:CGRect = CGRect.null
        for tokenView:CLTokenView in self.tokenViews {
            tokenRect = tokenView.frame
            
            let tokenBoundary:CGFloat = isOnFirstLine ? firstLineRightBoundary : rightBoundary
            if curX + tokenRect.width > tokenBoundary {
                // Need a new line
                curX = PADDING_LEFT
                curY += STANDARD_ROW_HEIGHT + VSPACE
                totalHeight += STANDARD_ROW_HEIGHT
                isOnFirstLine = false
            }
            
            tokenRect.origin.x = curX
            // Center our tokenView vertically within STANDARD_ROW_HEIGHT
            tokenRect.origin.y = curY + ((STANDARD_ROW_HEIGHT - tokenRect.height) / 2.0)
            tokenView.frame = tokenRect
            
            curX = tokenRect.maxX + HSPACE
        }
        
        // Always indent textfield by a little bit
        curX += TEXT_FIELD_HSPACE
        let textBoundary:CGFloat = isOnFirstLine ? firstLineRightBoundary : rightBoundary
        var availableWidthForTextField:CGFloat = textBoundary - curX;
        if availableWidthForTextField < MINIMUM_TEXTFIELD_WIDTH {
            isOnFirstLine = false
            curX = PADDING_LEFT + TEXT_FIELD_HSPACE
            curY += STANDARD_ROW_HEIGHT + VSPACE
            totalHeight += STANDARD_ROW_HEIGHT
            // Adjust the width
            availableWidthForTextField = rightBoundary - curX;
        }
        
        var textFieldRect:CGRect = self.textField.frame;
        textFieldRect.origin.x = curX
        textFieldRect.origin.y = curY + self.additionalTextFieldYOffset
        textFieldRect.size.width = availableWidthForTextField
        textFieldRect.size.height = STANDARD_ROW_HEIGHT
        self.textField.frame = textFieldRect
        
        let oldContentHeight:CGFloat = self.intrinsicContentHeight;
        self.intrinsicContentHeight = textFieldRect.maxY + PADDING_BOTTOM;
        self.invalidateIntrinsicContentSize()
        
        if oldContentHeight != self.intrinsicContentHeight {
            self.delegate?.tokenInputView(aView: self, didChangeHeightTo: self.intrinsicContentSize.height)
        }
        self.setNeedsDisplay()
    }
    
    func updatePlaceholderTextVisibility() {
        if self.tokens.count > 0 {
            self.textField.placeholder = nil
        }
        else {
            self.textField.placeholder = self.placeholderText
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.repositionViews()
    }
    
    
    // MARK: CLBackspaceDetectingTextFieldDelegate
    
    func textFieldDidDeleteBackwards(textField: UITextField) {
        DispatchQueue.main.async {
            if textField.text?.characters.count == 0 {
                let tokenView:CLTokenView? = self.tokenViews.last
                if tokenView != nil {
                    self.selectTokenView(tokenView: tokenView!, animated: true)
                    self.textField.resignFirstResponder()
                }
            }
        }
    }
    
    //MARK: UITextFieldDelegate
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        //print("textFieldDidBeginEditing:")
        self.delegate?.tokenInputViewDidBeginEditing(aView: self)
        
        self.tokenViews.last?.hideUnselectedComma = false
        self.unselectAllTokenViewsAnimated(animated: true)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        //print("textFieldDidEndEditing:")

        self.delegate?.tokenInputViewDidEndEditing(aView: self)
        self.tokenViews.last?.hideUnselectedComma = true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        //print("textFieldShouldReturn:")

        self.tokenizeTextfieldText()
        return false
    }
    
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        //print("textField:shouldChangeCharactersInRange:replacementString:\(string)")

        if string.characters.count > 0 && self.tokenizationCharacters.contains(string) {
            self.tokenizeTextfieldText()
            return false
        }
        return true
    }
    
    func onTextFieldDidChange(sender:UITextField) {
       // print("onTextFieldDidChange")
        self.delegate?.tokenInputView(aView: self, didChangeText: self.textField.text!)
    }
    
    
    func textFieldDisplayOffset() -> CGFloat {
        return self.textField.frame.minY - PADDING_TOP;
    }
    
    func text() -> String? {
        return self.textField.text
    }
    
    func tokenViewDidRequestDelete(tokenView:CLTokenView, replaceWithText replacementText:String?) {
        self.textField.becomeFirstResponder()
        if let text = replacementText, text.characters.count > 0 {
            self.textField.text = replacementText
        }
        let index:Int? = self.tokenViews.index(of: tokenView)
        if index == nil {
            return
        }
        self.removeTokenAtIndex(index: index!)
    }
    
    func tokenViewDidRequestSelection(tokenView:CLTokenView) {
        self.selectTokenView(tokenView: tokenView, animated:true)
    }
    
    func selectTokenView(tokenView:CLTokenView, animated aBool:Bool) {
        tokenView.setSelected(selectedBool: true, animated: aBool)
        for otherTokenView:CLTokenView in self.tokenViews {
            if otherTokenView != tokenView {
                otherTokenView.setSelected(selectedBool: false, animated: aBool)
            }
        }
    }
    
    func unselectAllTokenViewsAnimated(animated:Bool) {
        for tokenView:CLTokenView in self.tokenViews {
            tokenView.setSelected(selectedBool: false, animated: animated)
        }
    }
    
    
    //
    
    func isEditing() -> Bool {
        return self.textField.isEditing
    }
    
    func beginEditing() {
        self.textField.becomeFirstResponder()
        self.unselectAllTokenViewsAnimated(animated: false)
    }
    
    func endEditing() {
        self.textField.resignFirstResponder()
    }
    
    //
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        if let context = UIGraphicsGetCurrentContext(), self.drawBottomBorder == true {
            
            context.setStrokeColor(UIColor.lightGray.cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: self.bounds.width, y: self.bounds.size.height))
            context.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
            context.strokePath()
        }   
    }
}
