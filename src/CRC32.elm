module CRC32 exposing (crc32, calcCrc32, polyRemainder, reduce, crcTable, example, CRC32)

import Array
import Bitwise exposing (..)

{-
The CRC-32 algorithm was generously contributed by
David Schwaderer and can be found in his excellent
book "C Programmers Guide to NetBIOS" published by
Howard W. Sams & Co. Inc. The 'magic number' for
the CRC is 0xdebb20e3. The proper CRC pre and post
conditioning is used, meaning that the CRC register
is pre-conditioned with all ones (a starting value
of 0xffffffff) and the value is post-conditioned by
taking the one's complement of the CRC residual.
If bit 3 of the general purpose flag is set, this
field is set to zero in the local header and the correct
value is put in the data descriptor and in the central
directory. When encrypting the central directory, if the
local header is not in ZIP64 format and general purpose
bit flag 13 is set indicating masking, the value stored
in the Local Header will be zero
 -}
-- poly = 0xdebb20e3
poly = 0xedb88320 -- taken from rossetastone after verifying result for julia code equals unzip expected value


example = "The quick brown fox jumps over the lazy dog" |> String.toList |> List.map Char.toCode

reduce : (Int -> Int) -> Int -> Int -> Int
reduce step n rounds =
  if rounds <= 0 then
    n
  else
    reduce step (step n) (rounds - 1)


polyRemainder pol num =
  let
    step n =
      if (Bitwise.and 1 n) == 1
      then
        Bitwise.xor (Bitwise.shiftRightZfBy 1 n) pol
      else
        Bitwise.shiftRightZfBy 1 n
  in
    reduce step num 8


crcTable =
  let
    numbers = List.range 0 255
    table = List.map (polyRemainder poly) numbers
  in
    Array.fromList table


type alias CRC32 = { table : Array.Array Int }

crc32 = { table = crcTable }

{-

From wikipedia:

Function CRC32
   Input:
      data:  Bytes     //Array of bytes
   Output:
      crc32: UInt32    //32-bit unsigned crc-32 value

//Initialize crc-32 to starting value
crc32 ← 0xFFFFFFFF

for each byte in data do
   nLookupIndex ← (crc32 xor byte) and 0xFF;
   crc32 ← (crc32 shr 8) xor CRCTable[nLookupIndex] //CRCTable is an array of 256 32-bit constants

//Finalize the CRC-32 value by inverting all the bits
crc32 ← crc32 xor 0xFFFFFFFF
return crc32
-}
calcCrc32 crcdata data =
  let
      helper : Int -> Int -> Int
      helper byte last =
        let
            nLookupIndex = last |> Bitwise.and 0xff |> Bitwise.xor byte

            -- TODO: how do I get rid of this withDefault - i.e. prove it cannot happen and have a fast lookup without bounds check?
            lookedup = Array.get nLookupIndex crcdata.table |> Maybe.withDefault 0
        in
            last |> Bitwise.shiftRightZfBy 8 |> Bitwise.xor lookedup
      crc = List.foldr helper 0xffffffff (List.reverse data) -- 0xffffffff is called preconditioning
  in
      Bitwise.xor crc 0xffffffff -- this is called postconditioning

