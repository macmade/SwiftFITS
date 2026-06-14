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

public class FITSSection: CustomStringConvertible
{
    public enum Kind: CustomStringConvertible
    {
        case header
        case xtension
        case data

        public var description: String
        {
            switch self
            {
                case .header:   return "Header"
                case .xtension: return "Extension"
                case .data:     return "Data"
            }
        }
    }

    public                let kind:       Kind
    private               var blocks:     [ FITSBlock ]    = []
    public private( set ) var properties: [ FITSProperty ] = []

    public init( kind: Kind, block: FITSBlock? ) throws
    {
        self.kind = kind

        if let block = block
        {
            try self.append( block: block )
        }
    }

    public var dataSize: Int
    {
        self.blocks.reduce( 0 ) { $0 + $1.data.count }
    }

    public var data: Data
    {
        let size = self.dataSize
        var data = Data( capacity: size )

        self.blocks.forEach
        {
            data.append( $0.data )
        }

        return data
    }

    public var canAppendData: Bool
    {
        self.kind == .data || ( self.blocks.last?.hasEndMarker ?? false ) == false
    }

    public func append( block: FITSBlock ) throws
    {
        if self.kind == .header || self.kind == .xtension
        {
            if block.containsOnlyASCII == false
            {
                throw FITSError.invalidBlockData( reason: "Headers or extensions must contain only ASCII data" )
            }

            if let last = self.blocks.last
            {
                if last.hasEndMarker
                {
                    throw FITSError.invalidBlockData( reason: "Cannot append data to a section with an end marker" )
                }

                if block.hasExtensionMarker
                {
                    throw FITSError.invalidBlockData( reason: "Cannot append an extension to a header or extension with existing data" )
                }
            }
        }

        self.blocks.append( block )
    }

    public func finalize( options: FITSParsingOptions ) throws
    {
        if self.kind == .header || self.kind == .xtension
        {
            if options.contains( .allowNonPrintableHeaderText ) == false, self.data.containsOnlyFITSPrintable == false
            {
                throw FITSError.invalidSectionData( reason: "Header contains non-printable characters" )
            }

            let properties = try FITSSection.readAndMergeProperties( data: self.data, options: options )

            if properties.count( where: { $0.name == "END" } ) > 1
            {
                throw FITSError.invalidSectionData( reason: "Multiple end markers found" )
            }

            guard let index = properties.firstIndex( where: { $0.name == "END" } )
            else
            {
                throw FITSError.invalidSectionData( reason: "No end marker found" )
            }

            if options.contains( .allowUnknownProperties ) == false, let unknown = properties.first( where: { $0.value.kind == .unknown } )
            {
                throw FITSError.invalidSectionData( reason: "Unknown property found: \( unknown.name )" )
            }

            let lastNonEmpty = properties[ 0 ..< index ].lastIndex
            {
                $0.name.isEmpty == false || $0.value.kind != .undefined || $0.comment != nil
            }

            if let lastNonEmpty
            {
                self.properties = Array( properties[ 0 ... lastNonEmpty ] )
            }
            else
            {
                self.properties = Array( properties[ 0 ..< index ] )
            }
        }
    }

    private class func readAndMergeProperties( data: Data, options: FITSParsingOptions ) throws -> [ FITSProperty ]
    {
        try data.chunked( by: 80 ).map
        {
            try FITSProperty( data: $0, options: options )
        }
        .reduce( into: [ FITSProperty ]() )
        {
            if $1.name == "CONTINUE", options.contains( .mergeStringProperties )
            {
                guard let last = $0.last
                else
                {
                    throw FITSError.invalidSectionData( reason: "No previous property to continue" )
                }

                try last.merge( with: $1 )
            }
            else if let last = $0.last, last.name == "HISTORY", $1.name == "HISTORY", options.contains( .mergeHistoryProperties )
            {
                try last.merge( with: $1 )
            }
            else if let last = $0.last, last.name == "COMMENT", $1.name == "COMMENT", options.contains( .mergeCommentProperties )
            {
                try last.merge( with: $1 )
            }
            else
            {
                $0.append( $1 )
            }
        }
    }

    public var description: String
    {
        self.description( indent: 0 )
    }

    public func description( indent: Int ) -> String
    {
        let indent     = String( repeating: " ", count: indent * 4 )
        let dataSize   = self.dataSize
        let properties = if self.properties.isEmpty == false
        {
            """

            \( indent )    Properties:
            \( indent )    [
            \( indent )        \( self.properties.map { $0.description }.joined( separator: "\n\( indent )        " ) )
            \( indent )    ]
            """
        }
        else
        {
            ""
        }

        return """
            \( indent )FITSSection 
            \( indent ){
            \( indent )    Kind:       \( self.kind )
            \( indent )    Chunks:     \( self.blocks.count )
            \( indent )    Data Size:  \( dataSize )\( properties )
            \( indent )}
            """
    }
}
