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

/// The typed value of a FITS header property.
///
/// FITS values are one of a small set of scalar types. Two extra cases cover
/// records that carry no value (``undefined``) and values that match no known
/// type or cannot be represented exactly (``unknown``), the latter preserving
/// the original literal text.
public enum FITSValue: Equatable
{
    /// A logical (boolean) value, written `T` or `F` in the record.
    case logical( Bool )

    /// An integer value representable as an `Int64`.
    case integer( Int64 )

    /// A floating-point value.
    case float( Double )

    /// A character string value.
    case string( String )

    /// No value is associated with the property (e.g. `COMMENT`, `HISTORY`, or
    /// a keyword with no `=` value field).
    case undefined

    /// A value that matches no known FITS type, or matches the integer grammar
    /// but overflows `Int64`. The associated string holds the original literal.
    case unknown( String )

    /// The type discriminator of a ``FITSValue``, independent of any payload.
    ///
    /// Used to compare or validate a value's type without unwrapping it.
    public enum Kind: CustomStringConvertible
    {
        /// The kind of ``FITSValue/logical(_:)``.
        case logical

        /// The kind of ``FITSValue/integer(_:)``.
        case integer

        /// The kind of ``FITSValue/float(_:)``.
        case float

        /// The kind of ``FITSValue/string(_:)``.
        case string

        /// The kind of ``FITSValue/undefined``.
        case undefined

        /// The kind of ``FITSValue/unknown(_:)``.
        case unknown

        /// A human-readable name for the kind.
        public var description: String
        {
            switch self
            {
                case .logical:   return "Logical"
                case .integer:   return "Integer"
                case .float:     return "Float"
                case .string:    return "String"
                case .undefined: return "Undefined"
                case .unknown:   return "Unknown"
            }
        }
    }

    /// The ``Kind`` discriminator matching this value's case.
    public var kind: Kind
    {
        switch self
        {
            case .logical:   return .logical
            case .integer:   return .integer
            case .float:     return .float
            case .string:    return .string
            case .undefined: return .undefined
            case .unknown:   return .unknown
        }
    }

    /// The boolean payload, or `nil` if this is not a ``logical(_:)`` value.
    public var logical: Bool?
    {
        if case .logical( let value ) = self { value } else { nil }
    }

    /// The integer payload, or `nil` if this is not an ``integer(_:)`` value.
    public var integer: Int64?
    {
        if case .integer( let value ) = self { value } else { nil }
    }

    /// The floating-point payload, or `nil` if this is not a ``float(_:)`` value.
    public var float: Double?
    {
        if case .float( let value ) = self { value } else { nil }
    }

    /// The string payload, or `nil` if this is not a ``string(_:)`` value.
    public var string: String?
    {
        if case .string( let value ) = self { value } else { nil }
    }
}
