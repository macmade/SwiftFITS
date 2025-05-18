/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2025 Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Foundation
import Testing
@testable import SwiftFITS

struct Test_FITSSection
{
    @Test
    func initData() async throws
    {
        let block    = try #require( try? FITSBlock( data: TestUtilities.blockData( strings: [], asciiOnly: false ) ) )
        let section1 = try #require( try? FITSSection( kind: .data, block: block ) )
        let section2 = try #require( try? FITSSection( kind: .data, block: nil ) )
        
        try #require( section1.kind == .data )
        try #require( section2.kind == .data )
        
        try #require( section1.canAppendData == true )
        try #require( section2.canAppendData == true )
        
        try #require( section1.data.isEmpty == false )
        try #require( section2.data.isEmpty == true )
    }
    
    @Test
    func initHeader() async throws
    {
        let block1   = try #require( try? TestUtilities.headerBlock( includeEndMarker: true ) )
        let block2   = try #require( try? TestUtilities.headerBlock( includeEndMarker: false ) )
        let section1 = try #require( try? FITSSection( kind: .header, block: block1 ) )
        let section2 = try #require( try? FITSSection( kind: .header, block: block2 ) )
        let section3 = try #require( try? FITSSection( kind: .header, block: nil ) )
        
        try #require( section1.kind == .header )
        try #require( section2.kind == .header )
        try #require( section3.kind == .header )
        
        try #require( section1.canAppendData == false )
        try #require( section2.canAppendData == true )
        try #require( section3.canAppendData == true )
        
        try #require( section1.data.isEmpty == false )
        try #require( section2.data.isEmpty == false )
        try #require( section3.data.isEmpty == true )
    }
    
    @Test
    func initExtension() async throws
    {
        let block1   = try #require( try? TestUtilities.headerBlock( includeEndMarker: true ) )
        let block2   = try #require( try? TestUtilities.headerBlock( includeEndMarker: false ) )
        let section1 = try #require( try? FITSSection( kind: .xtension, block: block1 ) )
        let section2 = try #require( try? FITSSection( kind: .xtension, block: block2 ) )
        let section3 = try #require( try? FITSSection( kind: .xtension, block: nil ) )
        
        try #require( section1.kind == .xtension )
        try #require( section2.kind == .xtension )
        try #require( section3.kind == .xtension )
        
        try #require( section1.canAppendData == false )
        try #require( section2.canAppendData == true )
        try #require( section3.canAppendData == true )
        
        try #require( section1.data.isEmpty == false )
        try #require( section2.data.isEmpty == false )
        try #require( section3.data.isEmpty == true )
    }
    
    @Test
    func appendData() async throws
    {
        let block    = try #require( try? FITSBlock( data: TestUtilities.blockData( strings: [], asciiOnly: false ) ) )
        let section1 = try #require( try? FITSSection( kind: .data, block: block ) )
        let section2 = try #require( try? FITSSection( kind: .data, block: nil ) )
        
        #expect( throws: Never.self ) { try section1.append( block: block ) }
        #expect( throws: Never.self ) { try section2.append( block: block ) }
    }
    
    @Test
    func appendHeader() async throws
    {
        let block1   = try #require( try? TestUtilities.headerBlock( includeEndMarker: true ) )
        let block2   = try #require( try? TestUtilities.headerBlock( includeEndMarker: false ) )
        let section1 = try #require( try? FITSSection( kind: .header, block: block1 ) )
        let section2 = try #require( try? FITSSection( kind: .header, block: block2 ) )
        let section3 = try #require( try? FITSSection( kind: .header, block: nil ) )
        
        #expect( throws: FITSError.self ) { try section1.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: true ) ) ) }
        #expect( throws: Never.self     ) { try section2.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: true ) ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: true ) ) ) }
        
        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: false ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: false ) ) ) }
        
        #expect( throws: Never.self     ) { try section2.append( block: try TestUtilities.headerBlock( includeEndMarker: true ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try TestUtilities.headerBlock( includeEndMarker: true ) ) }
        
        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: true ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: true ) ) ) }
    }
    
    @Test
    func appendExtension() async throws
    {
        let block1   = try #require( try? TestUtilities.headerBlock( includeEndMarker: true ) )
        let block2   = try #require( try? TestUtilities.headerBlock( includeEndMarker: false ) )
        let section1 = try #require( try? FITSSection( kind: .xtension, block: block1 ) )
        let section2 = try #require( try? FITSSection( kind: .xtension, block: block2 ) )
        let section3 = try #require( try? FITSSection( kind: .xtension, block: nil ) )
        
        #expect( throws: FITSError.self ) { try section1.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: true ) ) ) }
        #expect( throws: Never.self     ) { try section2.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: true ) ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: true ) ) ) }
        
        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: false ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: false ) ) ) }
        
        #expect( throws: Never.self     ) { try section2.append( block: try TestUtilities.extensionBlock( includeEndMarker: true ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try TestUtilities.extensionBlock( includeEndMarker: true ) ) }
        
        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: true ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: try TestUtilities.blockData( strings: [], asciiOnly: true ) ) ) }
    }
}
