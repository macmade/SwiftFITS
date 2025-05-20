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
        let block    = try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ) )
        let section1 = try FITSSection( kind: .data, block: block )
        let section2 = try FITSSection( kind: .data, block: nil )
        
        #expect( section1.kind == .data )
        #expect( section2.kind == .data )
        
        #expect( section1.canAppendData == true )
        #expect( section2.canAppendData == true )
        
        #expect( section1.data.isEmpty == false )
        #expect( section2.data.isEmpty == true )
    }
    
    @Test
    func initHeader() async throws
    {
        let block1   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true,  keywords: [] ) )
        let block2   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [] ) )
        let section1 = try FITSSection( kind: .header, block: block1 )
        let section2 = try FITSSection( kind: .header, block: block2 )
        let section3 = try FITSSection( kind: .header, block: nil )
        
        #expect( section1.kind == .header )
        #expect( section2.kind == .header )
        #expect( section3.kind == .header )
        
        #expect( section1.canAppendData == false )
        #expect( section2.canAppendData == true )
        #expect( section3.canAppendData == true )
        
        #expect( section1.data.isEmpty == false )
        #expect( section2.data.isEmpty == false )
        #expect( section3.data.isEmpty == true )
    }
    
    @Test
    func initExtension() async throws
    {
        let block1   = try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true,  keywords: [] ) )
        let block2   = try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: false, keywords: [] ) )
        let section1 = try FITSSection( kind: .xtension, block: block1 )
        let section2 = try FITSSection( kind: .xtension, block: block2 )
        let section3 = try FITSSection( kind: .xtension, block: nil )
        
        #expect( section1.kind == .xtension )
        #expect( section2.kind == .xtension )
        #expect( section3.kind == .xtension )
        
        #expect( section1.canAppendData == false )
        #expect( section2.canAppendData == true )
        #expect( section3.canAppendData == true )
        
        #expect( section1.data.isEmpty == false )
        #expect( section2.data.isEmpty == false )
        #expect( section3.data.isEmpty == true )
    }
    
    @Test
    func appendData() async throws
    {
        let block    = try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ) )
        let section1 = try FITSSection( kind: .data, block: block )
        let section2 = try FITSSection( kind: .data, block: nil )
        
        #expect( throws: Never.self ) { try section1.append( block: block ) }
        #expect( throws: Never.self ) { try section2.append( block: block ) }
    }
    
    @Test
    func appendHeader() async throws
    {
        let block1   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true,  keywords: [] ) )
        let block2   = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [] ) )
        let section1 = try FITSSection( kind: .header, block: block1 )
        let section2 = try FITSSection( kind: .header, block: block2 )
        let section3 = try FITSSection( kind: .header, block: nil )
        
        #expect( throws: FITSError.self ) { try section1.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        #expect( throws: Never.self     ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        
        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ) ) ) }
        
        #expect( throws: Never.self     ) { try section2.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ) ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ) ) ) }
        
        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
    }
    
    @Test
    func appendExtension() async throws
    {
        let block1   = try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true,  keywords: [] ) )
        let block2   = try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: false, keywords: [] ) )
        let section1 = try FITSSection( kind: .xtension, block: block1 )
        let section2 = try FITSSection( kind: .xtension, block: block2 )
        let section3 = try FITSSection( kind: .xtension, block: nil )
        
        #expect( throws: FITSError.self ) { try section1.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        #expect( throws: Never.self     ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        #expect( throws: Never.self     ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        
        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0xFF ) ) ) }
        
        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true, keywords: [] ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: try TestUtilities.standardExtensionBlock( includeEndMarker: true, keywords: [] ) ) ) }
        
        #expect( throws: Never.self ) { try section2.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ) ) ) }
        #expect( throws: Never.self ) { try section3.append( block: try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [] ) ) ) }
        
        #expect( throws: FITSError.self ) { try section2.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
        #expect( throws: FITSError.self ) { try section3.append( block: try FITSBlock( data: TestUtilities.dataBlock( fill: 0x20 ) ) ) }
    }
    
    @Test
    func mergeHistory() async throws
    {
        let keywords = [ ( "HISTORY", "hello" ), ( "HISTORY", "world" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ) )
        let section  = try FITSSection( kind: .header, block: block )
        
        try section.finalize()
        
        let property = section.properties.filter { $0.name == "HISTORY" }.first
        
        #expect( property          != nil )
        #expect( property?.comment == "hello\nworld" )
    }
    
    @Test
    func mergeComment() async throws
    {
        let keywords = [ ( "COMMENT", "hello" ), ( "COMMENT", "world" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ) )
        let section  = try FITSSection( kind: .header, block: block )
        
        try section.finalize()
        
        let property = section.properties.filter { $0.name == "COMMENT" }.first
        
        #expect( property          != nil )
        #expect( property?.comment == "hello\nworld" )
    }
    
    @Test
    func mergeString() async throws
    {
        let keywords = [ ( "FOOBAR", "'hello&'" ), ( "CONTINUE", "', world'" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ) )
        let section  = try FITSSection( kind: .header, block: block )
        
        try section.finalize()
        
        let property = section.properties.filter { $0.name == "FOOBAR" }.first
        
        #expect( property                   != nil )
        #expect( property?.value as? String == "hello, world" )
    }
    
    @Test
    func mergeStringFail() async throws
    {
        let keywords = [ ( "FOOBAR", "'hello'" ), ( "CONTINUE", "', world'" ) ]
        let block    = try FITSBlock( data: try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: keywords ) )
        let section  = try FITSSection( kind: .header, block: block )
        
        #expect( throws: FITSError.self ) { try section.finalize() }
    }
}
