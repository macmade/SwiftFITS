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

public enum FITSError: LocalizedError, CustomStringConvertible
{
    case invalidFileURL( url: URL )
    case cannotReadFile( url: URL )
    case invalidBlockSize( size: Int )
    case invalidBlockData( reason: String )
    case invalidSectionData( reason: String )
    case invalidFileData( reason: String )
    case invalidPropertyData( reason: String )
    case dataError( reason: String )
    case genericError( reason: String )
    
    public var description: String
    {
        "FITS Error: \( self.errorDescription ?? "Unknown error" )"
    }
    
    public var errorDescription: String?
    {
        switch self
        {
            case let .invalidFileURL( url ):         return "Invalid file URL: \( url )"
            case let .cannotReadFile( url ):         return "Cannot read file: \( url )"
            case let .invalidBlockSize( size ):      return "Invalid block size: \( size )"
            case let .invalidBlockData( reason ):    return "Invalid block data: \( reason )"
            case let .invalidSectionData( reason ):  return "Invalid section data: \( reason )"
            case let .invalidFileData( reason ):     return "Invalid file data: \( reason )"
            case let .invalidPropertyData( reason ): return "Invalid property data: \( reason )"
            case let .dataError( reason ):           return "Data error: \( reason )"
            case let .genericError( reason ):        return "Generic error: \( reason )"
        }
    }
}
