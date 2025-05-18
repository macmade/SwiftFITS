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

class TestUtilities
{
    public static var testFiles: [ URL ]
    {
        Bundle( for: self ).urls( forResourcesWithExtension: "fits", subdirectory: nil ) ?? []
    }
    
    @Test
    func hasTestFiles() async throws
    {
        try #require( TestUtilities.testFiles.isEmpty == false )
    }
    
    class func blockData( strings: [ String ], asciiOnly: Bool ) throws -> Data
    {
        let data = try strings.reduce( into: Data() )
        {
            guard $1.count <= 80
            else
            {
                throw FITSError( message: "String is too long" )
            }
            
            guard let data = $1.padding( toLength: 80, withPad: "\u{20}", startingAt: 0 ).data( using: .ascii )
            else
            {
                throw FITSError( message: "Cannot convert string to ASCII data" )
            }
            
            $0.append( data )
        }
        
        try #require( data.count <= FITSFile.blockSize )
        
        if asciiOnly
        {
            return data + Data( repeating: 0x20, count: FITSFile.blockSize - data.count )
        }
        
        return data + Data( repeating: 0xFF, count: FITSFile.blockSize - data.count )
    }
    
    @Test
    func blockData() async throws
    {
        let _ = try #require( try? TestUtilities.blockData( strings: [], asciiOnly: false ) )
        let _ = try #require( try? TestUtilities.blockData( strings: [], asciiOnly: true ) )
        let _ = try #require( try? TestUtilities.blockData( strings: [ "foo", "bar" ], asciiOnly: false ) )
        let _ = try #require( try? TestUtilities.blockData( strings: [ "foo", "bar" ], asciiOnly: true ) )
        
        try #require( throws: FITSError.self ) { try TestUtilities.blockData( strings: [ String( repeating: " ", count: 100 ) ], asciiOnly: false ) }
        try #require( throws: FITSError.self ) { try TestUtilities.blockData( strings: [ "\u{FF}" ], asciiOnly: false ) }
    }
    
    class func headerBlock( includeEndMarker: Bool ) throws -> FITSBlock
    {
        let text =
        [
            "SIMPLE  =                    T / Standard FITS format",
            "BITPIX  =                   16 / Bits per data pixel",
            "NAXIS   =                    2 / Number of data axes",
            "NAXIS1  =                 1024 / Length of data axis 1",
            "NAXIS2  =                 1024 / Length of data axis 2",
            "END"
        ]
        .filter
        {
            includeEndMarker == false ? $0 != "END" : true
        }
        .map
        {
            $0.padding( toLength: 80, withPad: "\u{20}", startingAt: 0 )
        }
        .joined( separator: "" ).padding( toLength: 2880, withPad: "\u{20}", startingAt: 0 )
        
        guard let data = text.data( using: .ascii )
        else
        {
            throw FITSError( message: "Cannot convert string to ASCII data" )
        }
        
        return try FITSBlock( data: data )
    }
    
    @Test
    func headerBlock() async throws
    {
        let _ = try #require( try? TestUtilities.headerBlock( includeEndMarker: true ) )
        let _ = try #require( try? TestUtilities.headerBlock( includeEndMarker: false ) )
    }
    
    class func extensionBlock( includeEndMarker: Bool ) throws -> FITSBlock
    {
        let text =
        [
            "XTENSION= 'TABLE    '           / ASCII table extension",
            "BITPIX  =                   16 / Bits per data pixel",
            "NAXIS   =                    2 / Number of data axes",
            "NAXIS1  =                 1024 / Length of data axis 1",
            "NAXIS2  =                 1024 / Length of data axis 2",
            "END"
        ]
        .filter
        {
            includeEndMarker == false ? $0 != "END" : true
        }
        .map
        {
            $0.padding( toLength: 80, withPad: "\u{20}", startingAt: 0 )
        }
        .joined( separator: "" ).padding( toLength: 2880, withPad: "\u{20}", startingAt: 0 )
        
        guard let data = text.data( using: .ascii )
        else
        {
            throw FITSError( message: "Cannot convert string to ASCII data" )
        }
        
        return try FITSBlock( data: data )
    }
    
    @Test
    func extensionBlock() async throws
    {
        let _ = try #require( try? TestUtilities.extensionBlock( includeEndMarker: true ) )
        let _ = try #require( try? TestUtilities.extensionBlock( includeEndMarker: false ) )
    }
}
