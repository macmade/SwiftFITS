/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Foundation
@testable import SwiftFITS
import Testing

struct Test_Data
{
    @Test
    func containsOnlyASCII() async throws
    {
        let ascii = Data( ( 0 ... 0x7F ).map { $0 } )
        let bin   = Data( ( 0 ... 0xFF ).map { $0 } )

        #expect( ascii.containsOnlyASCII == true )
        #expect( bin.containsOnlyASCII   == false )
    }

    @Test
    func chunked() async throws
    {
        let data = Data( ( 0 ... 0xFF ).map { $0 } )

        #expect( try data.chunked( by:   1 ).count == 256 )
        #expect( try data.chunked( by:   2 ).count == 128 )
        #expect( try data.chunked( by:   4 ).count ==  64 )
        #expect( try data.chunked( by:   8 ).count ==  32 )
        #expect( try data.chunked( by:  16 ).count ==  16 )
        #expect( try data.chunked( by:  32 ).count ==   8 )
        #expect( try data.chunked( by:  64 ).count ==   4 )
        #expect( try data.chunked( by: 128 ).count ==   2 )
        #expect( try data.chunked( by: 256 ).count ==   1 )

        try #require( throws: FITSError.self ) { try data.chunked( by: 0 ) }
        try #require( throws: FITSError.self ) { try data.chunked( by: 3 ) }
    }
}
