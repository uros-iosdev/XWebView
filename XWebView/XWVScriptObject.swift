/*
 Copyright 2015 XWebView

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

import Foundation

public class XWVScriptObject : XWVObject {
    // Evaluate JavaScript string
    public func evaluateExpression(exp: String, error: NSErrorPointer = nil) -> AnyObject? {
        if let result: AnyObject = webView?.evaluateJavaScript(scriptForRetaining(exp), error: error) {
            return wrapScriptObject(result)
        }
        return nil
    }

    public func evaluateExpression(exp: String, onSuccess handler: ((AnyObject!)->Void)?) {
        if handler == nil {
            webView?.evaluateJavaScript(exp, completionHandler: nil)
        } else {
            webView?.evaluateJavaScript(scriptForRetaining(exp)) {
                [weak self](result: AnyObject!, error: NSError!)->Void in
                if self != nil && result != nil {
                    handler!(self!.wrapScriptObject(result!))
                }
            }
        }
    }

    // JavaScript object operations
    public func construct(# arguments: [AnyObject]?, resultHandler: ((AnyObject!)->Void)?) {
        let exp = "new " + scriptForCallingMethod(nil, arguments: arguments)
        evaluateExpression(exp, onSuccess: resultHandler)
    }
    public func call(# arguments: [AnyObject]?, resultHandler: ((AnyObject!)->Void)?) {
        let exp = scriptForCallingMethod(nil, arguments: arguments)
        evaluateExpression(exp, onSuccess: resultHandler)
    }
    public func callMethod(name: String, withArguments arguments: [AnyObject]?, resultHandler: ((AnyObject!)->Void)?) {
        let exp = scriptForCallingMethod(name, arguments: arguments)
        evaluateExpression(exp, onSuccess: resultHandler)
    }

    public func construct(# arguments: [AnyObject]?) -> AnyObject! {
        return evaluateExpression("new \(scriptForCallingMethod(nil, arguments: arguments))")
    }
    public func call(# arguments: [AnyObject]?) -> AnyObject! {
        return evaluateExpression(scriptForCallingMethod(nil, arguments: arguments))
    }
    public func callMethod(name: String, withArguments arguments: [AnyObject]?) -> AnyObject! {
        return evaluateExpression(scriptForCallingMethod(name, arguments: arguments))
    }

    public func defineProperty(name: String, descriptor: [String:AnyObject]) -> AnyObject? {
        let exp = "Object.defineProperty(\(namespace), \(name), \(serialize(descriptor)))"
        return evaluateExpression(exp)
    }
    public func deleteProperty(name: String) -> Bool {
        let result: AnyObject? = evaluateExpression("delete \(scriptForFetchingProperty(name))")
        return (result as? NSNumber)?.boolValue ?? false
    }
    public func hasProperty(name: String) -> Bool {
        let result: AnyObject? = evaluateExpression("\(scriptForFetchingProperty(name)) != undefined")
        return (result as? NSNumber)?.boolValue ?? false
    }

    public func value(forProperty name: String) -> AnyObject? {
        return evaluateExpression(scriptForFetchingProperty(name))
    }
    public func setValue(value: AnyObject?, forProperty name:String) {
        webView?.evaluateJavaScript(scriptForUpdatingProperty(name, value: value), completionHandler: nil)
    }
    public func value(atIndex index: UInt) -> AnyObject? {
        return evaluateExpression("\(namespace)[\(index)]")
    }
    public func setValue(value: AnyObject?, atIndex index: UInt) {
        webView?.evaluateJavaScript("\(namespace)[\(index)] = \(serialize(value))", completionHandler: nil)
    }

    private func scriptForRetaining(script: String) -> String {
        return "\(origin.namespace).$retainIfNeeded(\(script))"
    }
    private func scriptForFetchingProperty(name: String!) -> String {
        if name == nil {
            return namespace
        } else if name.isEmpty {
            return "\(namespace)['']"
        } else if let idx = name.toInt() {
            return "\(namespace)[\(idx)]"
        } else {
            return "\(namespace).\(name)"
        }
    }
    private func scriptForUpdatingProperty(name: String!, value: AnyObject?) -> String {
        return scriptForFetchingProperty(name) + " = " + serialize(value)
    }
    private func scriptForCallingMethod(name: String!, arguments: [AnyObject]?) -> String {
        let args = arguments?.map(serialize) ?? []
        return scriptForFetchingProperty(name) + "(" + ", ".join(args) + ")"
    }
}

extension XWVScriptObject {
    // Subscript support
    public subscript(name: String) -> AnyObject? {
        get {
            return value(forProperty: name)
        }
        set {
            setValue(newValue, forProperty: name)
        }
    }
    public subscript(index: UInt) -> AnyObject? {
        get {
            return value(atIndex: index)
        }
        set {
            setValue(newValue, atIndex: index)
        }
    }
}

extension XWVScriptObject {
    // DOM objects
    public var windowObject: XWVScriptObject {
        return XWVScriptObject(namespace: "window", channel: self.channel, origin: self.origin)
    }
    public var documentObject: XWVScriptObject {
        return XWVScriptObject(namespace: "document", channel: self.channel, origin: self.origin)
    }
}
