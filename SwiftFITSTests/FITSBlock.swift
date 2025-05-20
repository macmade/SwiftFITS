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

struct Test_FITSBlock
{
    @Test
    func containsOnlyASCII() async throws
    {
        let block1 = try FITSBlock( data: Data( repeating: 0x20, count: FITSFile.blockSize ) )
        let block2 = try FITSBlock( data: Data( repeating: 0xFF, count: FITSFile.blockSize ) )
        
        #expect( block1.containsOnlyASCII == true )
        #expect( block2.containsOnlyASCII == false )
    }
    
    @Test
    func hasEndMarker() async throws
    {
        let data1  = try TestUtilities.headerBlock( fields: [ ( "FOO     = 1" ), ( "BAR     = 1" ), ( "END        " ) ] )
        let data2  = try TestUtilities.headerBlock( fields: [ ( "FOO     = 1" ), ( "BAR     = 1" ), ( " END       " ) ] )
        let data3  = try TestUtilities.headerBlock( fields: [ ( "FOO     = 1" ), ( "END        " ), ( "BAR     = 1" ) ] )
        let block1 = try FITSBlock( data: data1 )
        let block2 = try FITSBlock( data: data2 )
        let block3 = try FITSBlock( data: data3 )
        
        #expect( block1.hasEndMarker == true )
        #expect( block2.hasEndMarker == false )
        #expect( block3.hasEndMarker == false )
    }
    
    @Test
    func hasExtensionMarker() async throws
    {
        let data1  = try TestUtilities.headerBlock( fields: [ ( "XTENSION  'TABLE    ' " ), ( "FOO     = 1          " ), ( "BAR     = 1" ) ] )
        let data2  = try TestUtilities.headerBlock( fields: [ ( "XTENSION= 'TABLE    ' " ), ( "FOO     = 1          " ), ( "BAR     = 1" ) ] )
        let data3  = try TestUtilities.headerBlock( fields: [ ( " XTENSION= 'TABLE    '" ), ( "FOO     = 1          " ), ( "BAR     = 1" ) ] )
        let data4  = try TestUtilities.headerBlock( fields: [ ( "FOO     = 1           " ), ( "XTENSION= 'TABLE    '" ), ( "BAR     = 1" ) ] )
        let block1 = try FITSBlock( data: data1 )
        let block2 = try FITSBlock( data: data2 )
        let block3 = try FITSBlock( data: data3 )
        let block4 = try FITSBlock( data: data4 )
        
        #expect( block1.hasExtensionMarker == false )
        #expect( block2.hasExtensionMarker == true )
        #expect( block3.hasExtensionMarker == false )
        #expect( block4.hasExtensionMarker == false )
    }
    
    @Test
    func hasEndMarkerAndExtensionMarker() async throws
    {
        let data  = try TestUtilities.standardExtensionBlock( includeEndMarker: true, keywords: [ ( "FOO", "1" ), ( "BAR", "1" ) ] )
        let block = try FITSBlock( data: data )
        
        #expect( block.hasEndMarker       == true )
        #expect( block.hasExtensionMarker == true )
    }
    
    @Test
    func binary() async throws
    {
        var data                       = try TestUtilities.standardHeaderBlock( includeEndMarker: false, keywords: [ ( "FOO", "1" ), ( "BAR", "1" ) ] )
        data[ FITSFile.blockSize - 1 ] = 0xFF
        let block                      = try FITSBlock( data: data )
        
        #expect( block.containsOnlyASCII == false )
    }
    
    @Test
    func binaryAndEndMarker() async throws
    {
        var data                       = try TestUtilities.standardHeaderBlock( includeEndMarker: true, keywords: [ ( "FOO", "1" ), ( "BAR", "1" ) ] )
        data[ FITSFile.blockSize - 1 ] = 0xFF
        let block                      = try FITSBlock( data: data )
        
        #expect( block.containsOnlyASCII == false )
        #expect( block.hasEndMarker      == false )
    }
    
    @Test
    func binaryAndExtensionMarker() async throws
    {
        var data                       = try TestUtilities.standardExtensionBlock( includeEndMarker: true, keywords: [ ( "FOO", "1" ), ( "BAR", "1" ) ] )
        data[ FITSFile.blockSize - 1 ] = 0xFF
        let block                      = try FITSBlock( data: data )
        
        #expect( block.containsOnlyASCII  == false )
        #expect( block.hasExtensionMarker == false )
    }
    
    @Test
    func initEmptyData() async throws
    {
        #expect( throws: FITSError.self ) { try FITSBlock( data: Data() ) }
    }
    
    @Test
    func description() async throws
    {
        let block = try FITSBlock( data: Data( repeating: 0x20, count: FITSFile.blockSize ) )
        
        #expect( block.description.isEmpty == false )
        #expect( block.description         != _typeName( FITSBlock.self, qualified: true ) )
    }
}
