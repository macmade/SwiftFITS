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

/// The errors thrown by SwiftFITS when reading or validating FITS data.
public enum FITSError: LocalizedError, CustomStringConvertible, Sendable
{
    /// The provided URL does not point to a readable file (e.g. it is missing
    /// or refers to a directory).
    case invalidFileURL( url: URL )

    /// The file at the given URL exists but its contents could not be read.
    case cannotReadFile( url: URL )

    /// A block does not have the mandatory 2880-byte FITS block size.
    case invalidBlockSize( size: Int )

    /// A block's contents are invalid for its role; `reason` describes the
    /// specific problem.
    case invalidBlockData( reason: String )

    /// A header or extension section is malformed; `reason` describes the
    /// specific problem.
    case invalidSectionData( reason: String )

    /// The overall file structure is invalid; `reason` describes the specific
    /// problem.
    case invalidFileData( reason: String )

    /// A single 80-byte header record could not be parsed; `reason` describes
    /// the specific problem.
    case invalidPropertyData( reason: String )

    /// A low-level data operation failed; `reason` describes the specific
    /// problem.
    case dataError( reason: String )

    /// A human-readable description prefixed with `FITS Error:`.
    public var description: String
    {
        "FITS Error: \( self.errorDescription ?? "Unknown error" )"
    }

    /// A localized message describing the error and its cause.
    public var errorDescription: String?
    {
        switch self
        {
            case .invalidFileURL( let url ):         return "Invalid file URL: \( url )"
            case .cannotReadFile( let url ):         return "Cannot read file: \( url )"
            case .invalidBlockSize( let size ):      return "Invalid block size: \( size )"
            case .invalidBlockData( let reason ):    return "Invalid block data: \( reason )"
            case .invalidSectionData( let reason ):  return "Invalid section data: \( reason )"
            case .invalidFileData( let reason ):     return "Invalid file data: \( reason )"
            case .invalidPropertyData( let reason ): return "Invalid property data: \( reason )"
            case .dataError( let reason ):           return "Data error: \( reason )"
        }
    }
}
