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
        let data  = try #require( try? TestUtilities.blockData( strings: [ "FOO", "BAR" ], asciiOnly: true ) )
        let block = try #require( try? FITSBlock( data: data ) )
        
        try #require( block.data.count         == FITSFile.blockSize )
        try #require( block.containsOnlyASCII  == true )
        try #require( block.hasEndMarker       == false )
        try #require( block.hasExtensionMarker == false )
    }
    
    @Test
    func hasEndMarker() async throws
    {
        let data1  = try #require( try? TestUtilities.blockData( strings: [ "FOO", "BAR", "END" ], asciiOnly: true ) )
        let data2  = try #require( try? TestUtilities.blockData( strings: [ "FOO", "BAR", " END" ], asciiOnly: true ) )
        let data3  = try #require( try? TestUtilities.blockData( strings: [ "FOO", "END", "BAR" ], asciiOnly: true ) )
        let block1 = try #require( try? FITSBlock( data: data1 ) )
        let block2 = try #require( try? FITSBlock( data: data2 ) )
        let block3 = try #require( try? FITSBlock( data: data3 ) )
        
        try #require( block1.data.count         == FITSFile.blockSize )
        try #require( block1.containsOnlyASCII  == true )
        try #require( block1.hasEndMarker       == true )
        try #require( block1.hasExtensionMarker == false )
        
        try #require( block2.data.count         == FITSFile.blockSize )
        try #require( block2.containsOnlyASCII  == true )
        try #require( block2.hasEndMarker       == false )
        try #require( block2.hasExtensionMarker == false )
        
        try #require( block3.data.count         == FITSFile.blockSize )
        try #require( block3.containsOnlyASCII  == true )
        try #require( block3.hasEndMarker       == false )
        try #require( block3.hasExtensionMarker == false )
    }
    
    @Test
    func hasExtensionMarker() async throws
    {
        let data1  = try #require( try? TestUtilities.blockData( strings: [ "XTENSION", "FOO", "BAR" ], asciiOnly: true ) )
        let data2  = try #require( try? TestUtilities.blockData( strings: [ "XTENSION=", "FOO", "BAR" ], asciiOnly: true ) )
        let data3  = try #require( try? TestUtilities.blockData( strings: [ " XTENSION=", "FOO", " BAR" ], asciiOnly: true ) )
        let data4  = try #require( try? TestUtilities.blockData( strings: [ "FOO", " XTENSION=", "BAR" ], asciiOnly: true ) )
        let block1 = try #require( try? FITSBlock( data: data1 ) )
        let block2 = try #require( try? FITSBlock( data: data2 ) )
        let block3 = try #require( try? FITSBlock( data: data3 ) )
        let block4 = try #require( try? FITSBlock( data: data4 ) )
        
        try #require( block1.data.count         == FITSFile.blockSize )
        try #require( block1.containsOnlyASCII  == true )
        try #require( block1.hasEndMarker       == false )
        try #require( block1.hasExtensionMarker == false )
        
        try #require( block2.data.count         == FITSFile.blockSize )
        try #require( block2.containsOnlyASCII  == true )
        try #require( block2.hasEndMarker       == false )
        try #require( block2.hasExtensionMarker == true )
        
        try #require( block3.data.count         == FITSFile.blockSize )
        try #require( block3.containsOnlyASCII  == true )
        try #require( block3.hasEndMarker       == false )
        try #require( block3.hasExtensionMarker == false )
        
        try #require( block4.data.count         == FITSFile.blockSize )
        try #require( block4.containsOnlyASCII  == true )
        try #require( block4.hasEndMarker       == false )
        try #require( block4.hasExtensionMarker == false )
    }
    
    @Test
    func hasEndMarker_hasExtensionMarker() async throws
    {
        let data  = try #require( try? TestUtilities.blockData( strings: [ "XTENSION=", "FOO", "BAR", "END" ], asciiOnly: true ) )
        let block = try #require( try? FITSBlock( data: data ) )
        
        try #require( block.data.count         == FITSFile.blockSize )
        try #require( block.containsOnlyASCII  == true )
        try #require( block.hasEndMarker       == true )
        try #require( block.hasExtensionMarker == true )
    }
    
    @Test
    func binary() async throws
    {
        let data1  = try #require( try? TestUtilities.blockData( strings: [], asciiOnly: false ) )
        let data2  = try #require( try? TestUtilities.blockData( strings: [ "FOO", "BAR" ], asciiOnly: false ) )
        let block1 = try #require( try? FITSBlock( data: data1 ) )
        let block2 = try #require( try? FITSBlock( data: data2 ) )
        
        try #require( block1.data.count         == FITSFile.blockSize )
        try #require( block1.containsOnlyASCII  == false )
        try #require( block1.hasEndMarker       == false )
        try #require( block1.hasExtensionMarker == false )
        
        try #require( block2.data.count         == FITSFile.blockSize )
        try #require( block2.containsOnlyASCII  == false )
        try #require( block2.hasEndMarker       == false )
        try #require( block2.hasExtensionMarker == false )
    }
    
    @Test
    func binaryAndEndMarker() async throws
    {
        let data  = try #require( try? TestUtilities.blockData( strings: [ "FOO", "BAR", "END" ], asciiOnly: false ) )
        let block = try #require( try? FITSBlock( data: data ) )
        
        try #require( block.data.count         == FITSFile.blockSize )
        try #require( block.containsOnlyASCII  == false )
        try #require( block.hasEndMarker       == false )
        try #require( block.hasExtensionMarker == false )
    }
    
    @Test
    func binaryAndExtensionMarker() async throws
    {
        let data  = try #require( try? TestUtilities.blockData( strings: [ "XTENSION=", "BAR" ], asciiOnly: false ) )
        let block = try #require( try? FITSBlock( data: data ) )
        
        try #require( block.data.count         == FITSFile.blockSize )
        try #require( block.containsOnlyASCII  == false )
        try #require( block.hasEndMarker       == false )
        try #require( block.hasExtensionMarker == false )
    }
}
