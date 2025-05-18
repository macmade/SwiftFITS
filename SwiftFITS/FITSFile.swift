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

public class FITSFile: CustomStringConvertible
{
    public static let blockSize = 2880
    
    public private( set ) var sections: [ FITSSection ]
    
    public convenience init( url: URL ) throws
    {
        var isDir: ObjCBool = false
        
        guard FileManager.default.fileExists( atPath: url.path, isDirectory: &isDir ), isDir.boolValue == false
        else
        {
            throw FITSError.invalidFileURL( url: url )
        }
        
        do
        {
            let data = try Data( contentsOf: url )
            
            try self.init( data: data )
        }
        catch let error as FITSError
        {
            throw error
        }
        catch
        {
            throw FITSError.cannotReadFile( url: url )
        }
    }
    
    public init( data: Data ) throws
    {
        guard data.isEmpty == false
        else
        {
            throw FITSError.dataError( reason: "Data is empty" )
        }
        
        let blocks = try data.chunked( by: FITSFile.blockSize ).map
        {
            try FITSBlock( data: $0 )
        }
        
        let sections = try blocks.reduce( into: [ FITSSection ]() )
        {
            if let last = $0.last
            {
                if $1.hasExtensionMarker
                {
                    $0.append( try FITSSection( kind: .xtension, block: $1 ) )
                }
                else if last.canAppendData
                {
                    try last.append( block: $1 )
                }
                else
                {
                    $0.append( try FITSSection( kind: .data, block: $1 ) )
                }
            }
            else
            {
                $0.append( try FITSSection( kind: .header, block: $1 ) )
            }
        }
        
        try sections.forEach
        {
            try $0.finalize()
        }
        
        self.sections = sections
    }
    
    public var data: Data
    {
        self.sections.reduce( Data() ) { $0 + $1.data }
    }
    
    public var description: String
    {
        """
        FITSFile
        {
            Sections:
            [
        \( self.sections.map { $0.description( indent: 2 ) }.joined( separator: "\n" ) )
            ]
        }
        """
    }
}
