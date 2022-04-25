//
//  SwiftTest.swift
//  TraceDemo
//
//

import UIKit

class SwiftTest: NSObject {
    @objc class public func swiftTest(){
        print("Swift Test ...")
        swiftPrivateFunc();
    }
    
    private class func swiftPrivateFunc() {
        print("swiftPrivateFunc ...")

    }
}
