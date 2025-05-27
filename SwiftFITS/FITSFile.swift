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

public class FITSFile: CustomStringConvertible
{
    public static let blockSize = 2880

    public private( set ) var sections: [ FITSSection ]

    public convenience init( url: URL, options: FITSParsingOptions = .standard ) throws
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

            try self.init( data: data, options: options )
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

    public init( data: Data, options: FITSParsingOptions = .standard ) throws
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
            if $1.hasExtensionMarker
            {
                $0.append( try FITSSection( kind: .xtension, block: $1 ) )
            }
            else if let last = $0.last
            {
                if last.canAppendData
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
            try $0.finalize( options: options )
        }

        guard let header = sections.first
        else
        {
            throw FITSError.invalidFileData( reason: "No sections" )
        }

        guard header.kind == .header
        else
        {
            throw FITSError.invalidFileData( reason: "First section is not a header" )
        }

        try FITSFile.validate( index: 0, in: header.properties, name: "SIMPLE", kind: .logical )
        {
            guard $0 as? Bool == true
            else
            {
                throw FITSError.invalidFileData( reason: "Invalid value for SIMPLE property" )
            }
        }

        try FITSFile.validate( index: 1, in: header.properties, name: "BITPIX", kind: .integer )
        {
            guard let value = $0 as? Int64, [ 8, 16, 32, 64, -32, 64 ].contains( value )
            else
            {
                throw FITSError.invalidFileData( reason: "Invalid value for BITPIX property" )
            }
        }

        try FITSFile.validate( index: 2, in: header.properties, name: "NAXIS",  kind: .integer )

        let naxis = header.properties[ 2 ].value as? Int64 ?? 0

        guard naxis >= 0, naxis <= Int.max
        else
        {
            throw FITSError.invalidFileData( reason: "Invalid value for NAXIS property (\( naxis )" )
        }

        try ( 0 ..< naxis ).forEach
        {
            index in try FITSFile.validate( index: Int( index + 3 ), in: header.properties, name: "NAXIS\( index + 1 )", kind: .integer )
            {
                guard let value = $0 as? Int64, value >= 0
                else
                {
                    throw FITSError.invalidFileData( reason: "Invalid value for NAXIS\( index + 1 ) property" )
                }
            }
        }

        self.sections = sections
    }

    public class func validate( index: Int, in properties: [ FITSProperty ], name: String, kind: FITSProperty.Kind, validate: ( ( Any? ) throws -> Void )? = nil ) throws
    {
        guard properties.count > index
        else
        {
            throw FITSError.invalidFileData( reason: "Missing property \( name ) expected at index \( index )" )
        }

        guard properties[ index ].name == name
        else
        {
            throw FITSError.invalidFileData( reason: "Missing property \( name ) expected at index \( index ) - Found \( properties[ index ].name ) instead" )
        }

        guard properties[ index ].kind == kind
        else
        {
            throw FITSError.invalidFileData( reason: "Invalid type for property \( name ) at index \( index ) - Expected \( kind ) but found \( properties[ index ].kind )" )
        }

        try validate?( properties[ index ].value )
    }

    public var data: Data
    {
        let sections = self.sections.map { $0.data }
        let size     = self.sections.reduce( 0 ) { $0 + $1.data.count }
        var data     = Data( capacity: size )

        sections.forEach
        {
            data.append( $0 )
        }

        return data
    }

    public var header: FITSSection?
    {
        return self.sections.first
    }

    public var extensions: [ FITSSection ]
    {
        return self.sections.filter { $0.kind == .xtension }
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
