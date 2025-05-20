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

struct Test_FITSFile
{
    @Test
    func parseAllTestFiles() async throws
    {
        try TestUtilities.testFiles.forEach
        {
            let _ = try FITSFile( url: $0 )
        }
    }
    
    @Test
    func invalidURL() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( url: URL( fileURLWithPath: "/foo/bar.fits" ) ) }
    }
    
    @Test
    func emptyData() async throws
    {
        #expect( throws: FITSError.self ) { try FITSFile( data: Data() ) }
    }
    
    @Test
    func data() async throws
    {
        let url  = try #require( TestUtilities.testFiles.first { $0.lastPathComponent == "FOSy19g0309t_c2f.fits" } )
        let file = try FITSFile( url: url )
        let copy = try FITSFile( data: file.data )
        
        #expect( file.data        == copy.data )
        #expect( file.description == copy.description )
    }
    
    @Test
    func description() async throws
    {
        let url  = try #require( TestUtilities.testFiles.first { $0.lastPathComponent == "FOSy19g0309t_c2f.fits" } )
        let file = try FITSFile( url: url )
        
        #expect( file.description.isEmpty == false )
        #expect( file.description         != _typeName( FITSFile.self, qualified: true ) )
    }
}
