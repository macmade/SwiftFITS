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

public enum FITSValue: Equatable
{
    case logical( Bool )
    case integer( Int64 )
    case float( Double )
    case string( String )
    case undefined
    case unknown( String )

    public enum Kind: CustomStringConvertible
    {
        case logical
        case integer
        case float
        case string
        case undefined
        case unknown

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

    public var logical: Bool?
    {
        if case .logical( let value ) = self { value } else { nil }
    }

    public var integer: Int64?
    {
        if case .integer( let value ) = self { value } else { nil }
    }

    public var float: Double?
    {
        if case .float( let value ) = self { value } else { nil }
    }

    public var string: String?
    {
        if case .string( let value ) = self { value } else { nil }
    }
}
