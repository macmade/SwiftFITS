/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com
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

/// A contiguous run of FITS blocks forming one logical unit.
///
/// A section is either the primary header, an extension header, or a data
/// segment. Header and extension sections parse their blocks into
/// ``properties``; data sections retain their raw blocks. Blocks are appended
/// as the file is scanned, then ``finalize(options:)`` parses and validates
/// the accumulated content.
///
/// A section holds mutable parsing state and composes ``FITSBlock``, so it is
/// not thread-safe and not `Sendable`.
public class FITSSection: CustomStringConvertible
{
    /// The role a ``FITSSection`` plays in the file.
    public enum Kind: CustomStringConvertible, Sendable
    {
        /// The primary header (the first section of the file).
        case header

        /// An extension header introduced by an `XTENSION` block.
        case xtension

        /// A data segment following a header or extension.
        case data

        /// A human-readable name for the kind.
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

    /// The role this section plays in the file.
    public let kind: Kind

    /// The raw blocks making up the section, in file order.
    private var blocks: [ FITSBlock ] = []

    /// Whether ``finalize(options:)`` has completed, after which structural
    /// blocks can no longer be appended (so ``properties`` and ``blocks`` cannot
    /// disagree).
    private var isFinalized = false

    /// Whether the section's model has diverged from its retained ``blocks`` and
    /// must be re-rendered on serialization instead of re-emitting those bytes.
    ///
    /// A freshly-parsed section is clean (`false`); building one from a model, or
    /// (later) mutating one, sets this. It is independent of ``isFinalized``: a
    /// section can be both finalized (locked against block appends) and in need
    /// of re-serialization.
    private var needsSerialization = false

    /// The data payload of a synthetically-built data section, or `nil` for a
    /// parsed section, whose bytes live in ``blocks``.
    private let payload: Data?

    /// The parsed header records. Empty for data sections, and until
    /// ``finalize(options:)`` has run.
    ///
    /// The `END` marker is excluded from this list, but it round-trips through
    /// ``data`` since the raw block bytes are retained.
    public private( set ) var properties: [ FITSProperty ] = []

    /// The first property whose keyword name matches, or `nil` if none does.
    ///
    /// A thin, read-only convenience over ``properties``. When a keyword appears
    /// more than once it returns the first occurrence, matching the
    /// first-wins resolution the parser uses for geometry keywords.
    ///
    /// - Parameter keyword: The keyword name to look up.
    /// - Returns: The first matching property, or `nil`.
    public subscript( keyword: String ) -> FITSProperty?
    {
        self.properties.first { $0.name == keyword }
    }

    /// The `BITPIX` value, or `nil` if the keyword is absent or not an integer.
    public var bitpix: Int64?
    {
        self[ "BITPIX" ]?.value.integer
    }

    /// The `NAXIS` value, or `nil` if the keyword is absent or not an integer.
    public var naxis: Int64?
    {
        self[ "NAXIS" ]?.value.integer
    }

    /// The `NAXISn` value for axis `n`, or `nil` if the keyword is absent or not
    /// an integer.
    ///
    /// - Parameter n: The 1-based axis index.
    /// - Returns: The parsed `NAXISn` value, or `nil`.
    public func naxis( _ n: Int ) -> Int64?
    {
        self[ "NAXIS\( n )" ]?.value.integer
    }

    /// Creates a section of the given kind, optionally seeded with a first block.
    ///
    /// - Parameters:
    ///   - kind: The role this section plays.
    ///   - block: An initial block to append, or `nil` to start empty.
    /// - Throws: ``FITSError/invalidBlockData(reason:)`` if the initial block
    ///   is not valid for the section kind.
    public init( kind: Kind, block: FITSBlock? ) throws
    {
        self.kind    = kind
        self.payload = nil

        if let block = block
        {
            try self.append( block: block )
        }
    }

    /// Creates a synthetic data section from a raw payload.
    ///
    /// The section is marked as needing serialization, so
    /// ``serializedData(options:)`` renders the payload (zero-padded to the block
    /// boundary) rather than re-emitting retained blocks, of which it has none.
    ///
    /// - Parameter dataPayload: The data-segment bytes, of any length.
    internal init( dataPayload: Data )
    {
        self.kind               = .data
        self.payload            = dataPayload
        self.needsSerialization = true
        self.isFinalized        = true
    }

    /// Marks the section as needing re-serialization from its model.
    ///
    /// Mutating a section's properties or data must call this so
    /// ``serializedData(options:)`` re-renders from the model instead of
    /// re-emitting the retained blocks.
    internal func markNeedsSerialization()
    {
        self.needsSerialization = true
    }

    /// The total size, in bytes, of the section's retained blocks.
    ///
    /// This reflects the bytes as parsed; a section pending re-serialization may
    /// render to a different size.
    public var dataSize: Int
    {
        self.blocks.reduce( 0 ) { $0 + $1.data.count }
    }

    /// The section's retained raw bytes, exactly as parsed.
    private var retainedBytes: Data
    {
        var data = Data( capacity: self.dataSize )

        self.blocks.forEach { data.append( $0.data ) }

        return data
    }

    /// The section's serialized bytes, rendered with the ``strict`` options.
    ///
    /// A convenience for ``serializedData(options:)`` with
    /// ``FITSSerializationOptions/strict``. A clean parsed section yields its
    /// retained bytes byte-for-byte; a section pending re-serialization is
    /// rendered from its model, which can fail.
    ///
    /// - Throws: Any ``FITSError`` raised while rendering a section that needs
    ///   serialization.
    public var data: Data
    {
        get throws
        {
            try self.serializedData( options: .strict )
        }
    }

    /// The section's serialized bytes.
    ///
    /// Returns the retained blocks unchanged when the section is clean (so an
    /// unmodified parsed section round-trips byte-for-byte), and renders from the
    /// model when the section needs serialization.
    ///
    /// - Parameter options: The serialization options to apply when rendering.
    /// - Returns: The section's bytes, a whole number of 2880-byte blocks.
    /// - Throws: Any ``FITSError`` raised while rendering.
    public func serializedData( options: FITSSerializationOptions ) throws -> Data
    {
        var data = Data( capacity: self.dataSize )

        try self.appendSerializedData( to: &data, options: options )

        return data
    }

    /// Appends the section's serialized bytes to an existing buffer.
    ///
    /// Lets a caller assemble several sections into one buffer without an
    /// intermediate ``Data`` copy per section. Routes to the retained blocks when
    /// clean and to the model renderer when the section needs serialization.
    ///
    /// - Parameters:
    ///   - data: The buffer to append to.
    ///   - options: The serialization options to apply when rendering.
    /// - Throws: Any ``FITSError`` raised while rendering.
    internal func appendSerializedData( to data: inout Data, options: FITSSerializationOptions ) throws
    {
        guard self.needsSerialization
        else
        {
            data.append( self.retainedBytes )

            return
        }

        switch self.kind
        {
            case .header, .xtension: data.append( try self.renderedHeader( options: options ) )
            case .data:              data.append( self.renderedDataSegment() )
        }
    }

    /// Renders a header or extension section from its ``properties``.
    ///
    /// Serializes every property to its card(s), appends the `END` marker, and
    /// blank-pads the result to a whole number of 2880-byte blocks (FITS 4.0
    /// §3.3.1).
    ///
    /// - Parameter options: The serialization options to apply.
    /// - Returns: The rendered header bytes.
    /// - Throws: ``FITSError/cannotSerialize(reason:)`` if the rendered text is
    ///   not ASCII, or any error raised while rendering a property.
    private func renderedHeader( options: FITSSerializationOptions ) throws -> Data
    {
        let cards = try self.properties.flatMap { try $0.serialized( options: options ) }
        let end   = "END".padding( toLength: FITSFile.cardSize, withPad: " ", startingAt: 0 )

        guard let ascii = ( cards + [ end ] ).joined().data( using: .ascii )
        else
        {
            throw FITSError.cannotSerialize( reason: "Header contains non-ASCII characters" )
        }

        return FITSSection.paddedToBlockBoundary( ascii, fill: 0x20 )
    }

    /// Renders a data section from its payload, zero-padded to the block boundary
    /// (FITS 4.0 §3.3.2).
    ///
    /// - Returns: The rendered data-segment bytes.
    private func renderedDataSegment() -> Data
    {
        FITSSection.paddedToBlockBoundary( self.payload ?? self.retainedBytes, fill: 0x00 )
    }

    /// Pads a buffer to a whole number of 2880-byte blocks.
    ///
    /// - Parameters:
    ///   - data: The bytes to pad.
    ///   - fill: The byte to pad with (ASCII space for headers, zero for data).
    /// - Returns: `data` padded to the next block boundary, or unchanged if it is
    ///   already block-aligned.
    private static func paddedToBlockBoundary( _ data: Data, fill: UInt8 ) -> Data
    {
        let remainder = data.count % FITSFile.blockSize

        guard remainder != 0
        else
        {
            return data
        }

        return data + Data( repeating: fill, count: FITSFile.blockSize - remainder )
    }

    /// Appends a block to the section.
    ///
    /// For header and extension sections this enforces structural rules: the
    /// block must be ASCII, must not follow an `END` marker, and must not
    /// introduce a new extension mid-section.
    ///
    /// - Parameter block: The block to append.
    /// - Throws: ``FITSError/invalidSectionData(reason:)`` if the section is
    ///   already finalized, or ``FITSError/invalidBlockData(reason:)`` if
    ///   appending the block would violate the structural rules.
    internal func append( block: FITSBlock ) throws
    {
        guard self.isFinalized == false
        else
        {
            throw FITSError.invalidSectionData( reason: "Cannot append to a finalized section" )
        }

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

    /// Appends a trailing padding block as-is.
    ///
    /// Bypasses the header structural rules so blank end-of-file padding
    /// round-trips through ``data`` without being parsed as content.
    ///
    /// - Parameter block: The padding block to retain.
    internal func append( padding block: FITSBlock )
    {
        self.blocks.append( block )
    }

    /// Parses and validates a header or extension section's accumulated blocks.
    ///
    /// Verifies printability, reads and merges the 80-byte records into
    /// ``properties``, enforces a single `END` marker, optionally rejects
    /// unknown-typed records, and trims trailing blank records up to the `END`
    /// marker. Has no effect on data sections.
    ///
    /// - Parameter options: The parsing options to apply.
    /// - Throws: ``FITSError/invalidSectionData(reason:)`` if the section is
    ///   already finalized, non-printable, has no or multiple `END` markers, or
    ///   contains an unknown property when not permitted.
    internal func finalize( options: FITSParsingOptions ) throws
    {
        guard self.isFinalized == false
        else
        {
            throw FITSError.invalidSectionData( reason: "Section already finalized" )
        }

        if self.kind == .header || self.kind == .xtension
        {
            let data = self.retainedBytes

            if options.contains( .allowNonPrintableHeaderText ) == false, data.containsOnlyFITSPrintable == false
            {
                throw FITSError.invalidSectionData( reason: "Header contains non-printable characters" )
            }

            let properties = try FITSSection.readAndMergeProperties( data: data, options: options )

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

            func isNonBlank( _ property: FITSProperty ) -> Bool
            {
                property.name.isEmpty == false || property.value.kind != .undefined || property.comment != nil
            }

            // FITS 4.0 allows only blank padding after END. allowContentAfterEnd
            // keeps the noncompliant records out of properties but tolerates them.
            if options.contains( .allowContentAfterEnd ) == false, properties[ ( index + 1 )... ].contains( where: isNonBlank )
            {
                throw FITSError.invalidSectionData( reason: "Non-blank content found after END marker" )
            }

            let lastNonEmpty = properties[ 0 ..< index ].lastIndex( where: isNonBlank )

            // Keep everything up to the last non-blank record, dropping trailing
            // blanks before END. With no non-blank record the section is empty.
            if let lastNonEmpty
            {
                self.properties = Array( properties[ 0 ... lastNonEmpty ] )
            }
            else
            {
                self.properties = []
            }
        }

        self.isFinalized = true
    }

    /// Splits header data into 80-byte records and merges continuation records.
    ///
    /// Each 80-byte chunk becomes a ``FITSProperty``; `CONTINUE`, `HISTORY` and
    /// `COMMENT` records are folded into their predecessor when the
    /// corresponding merge option is enabled.
    ///
    /// - Parameters:
    ///   - data: The full ASCII bytes of the header or extension.
    ///   - options: The parsing options to apply.
    /// - Returns: The parsed (and merged) properties in file order.
    /// - Throws: ``FITSError`` if a record cannot be parsed, or
    ///   ``FITSError/invalidSectionData(reason:)`` if a continuation record has
    ///   no predecessor to merge into.
    private class func readAndMergeProperties( data: Data, options: FITSParsingOptions ) throws -> [ FITSProperty ]
    {
        try data.chunked( by: FITSFile.cardSize ).map
        {
            try FITSProperty( data: $0, options: options )
        }
        .reduce( into: [ FITSProperty ]() )
        {
            if $1.name == "CONTINUE", options.contains( .mergeStringProperties )
            {
                do
                {
                    guard let last = $0.last
                    else
                    {
                        throw FITSError.invalidSectionData( reason: "No previous property to continue" )
                    }

                    try last.merge( with: $1 )
                }
                catch
                {
                    // A CONTINUE with no predecessor, or one whose predecessor is
                    // not a &-terminated string, cannot be merged.
                    // allowOrphanedContinue keeps it as a standalone property
                    // rather than rejecting the section.
                    guard options.contains( .allowOrphanedContinue )
                    else
                    {
                        throw error
                    }

                    $0.append( $1 )
                }
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

    /// A multi-line, human-readable summary of the section.
    public var description: String
    {
        self.description( indent: 0 )
    }

    /// A multi-line, human-readable summary of the section, indented for nesting.
    ///
    /// - Parameter indent: The indentation depth, in units of four spaces.
    /// - Returns: The formatted description.
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
