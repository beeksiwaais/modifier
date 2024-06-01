import Foundation
import Cocoa
import AppKit
import JavaScriptCore

class CustomView: NSView {
    var currentIndex: Int = 0
    var clipboardLabel: NSTextField?
    var modifiedLabel: NSTextField?
    var textField: NSTextField?
    var tableView: NSTableView?

    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    /*override func keyDown(with event: NSEvent) {
        let clipboardHistory = ClipboardManager.shared.clipboardHistory
        switch event.keyCode {
        case 126: // Up arrow
            if currentIndex > 0 {
                currentIndex -= 1
                updateClipboardLabel()
            }
        case 125: // Down arrow
            if currentIndex < clipboardHistory.count - 1 {
                currentIndex += 1
                updateClipboardLabel()
            }
        default:
            super.keyDown(with: event)
        }
    }*/
    
    func updateClipboardLabel() {
        print("update UI")
        let clipboardHistory = ClipboardManager.shared.clipboardHistory
        currentIndex = clipboardHistory.count - 1
        clipboardLabel?.stringValue = clipboardHistory[currentIndex].content
        tableView?.reloadData()
    }
}


struct ModifierEntry {
    let name: String
    let description: String
    let script: String
}



// JavaScript script for UTF-8 to Hex conversion
let utf8ToHexScript = """
function modify(input) {
    return input.split('').map(function(c) {
        return c.charCodeAt(0).toString(16).toUpperCase();
    }).join('');
}
"""

// Function to apply a JavaScript modifier to a string
func applyJavaScriptModifier(script: String, input: String) -> String {
    let context = JSContext()
    guard let context = context else {
        return input
    }

    context.evaluateScript(script)
    
    let modify = context.objectForKeyedSubscript("modify")
    
    if let result = modify?.call(withArguments: [input]) {
        return result.toString() ?? input
    } else {
        return input
    }
}

// Function to create and display the search box
func showSearchBox(clipboardHistory: [ClipboardEntry], completion: @escaping (String) -> Void) {
    let app = NSApplication.shared
    let delegate = AppDelegate(completion: completion)
    app.delegate = delegate
    app.run()
}

    
showSearchBox(clipboardHistory: ClipboardManager.shared.clipboardHistory) { input in
    let modifiedContent = applyJavaScriptModifier(script: utf8ToHexScript, input: input)
    // put modified content into clipboard
    ClipboardManager.shared.setClipboardContent(modifiedContent)
    print("Original Content: \(input)")
    print("Modified Content: \(modifiedContent)")
}


RunLoop.main.run()
