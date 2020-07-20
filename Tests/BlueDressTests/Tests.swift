//
//  File.swift
//  
//
//  Created by Tomoya Hirano on 2020/07/21.
//

import XCTest
@testable import BlueDress

class Tests: XCTestCase {
    func testMetalLibrary() {
        let library = try! MTLCreateSystemDefaultDevice()!.makeModuleLibrary()
        XCTAssertEqual(library.functionNames.count, 2)
        XCTAssertEqual(library.functionNames[0], "fragmentShader")
        XCTAssertEqual(library.functionNames[1], "vertexShader")
    }
}
