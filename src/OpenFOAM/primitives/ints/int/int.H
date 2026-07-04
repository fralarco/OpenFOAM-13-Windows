/*---------------------------------------------------------------------------*\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Copyright (C) 2011-2018 OpenFOAM Foundation
     \\/     M anipulation  |
-------------------------------------------------------------------------------
License
    This file is part of OpenFOAM.

    OpenFOAM is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    OpenFOAM is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
    for more details.

    You should have received a copy of the GNU General Public License
    along with OpenFOAM.  If not, see <http://www.gnu.org/licenses/>.

Primitive
    int

Description
    System integer

SourceFiles
    intIO.C

\*---------------------------------------------------------------------------*/

#ifndef int_H
#define int_H

#include "int32.H"
#include "int64.H"

#if defined(_WIN32)
#include "uint32.H"
#endif

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

namespace Foam
{

#define MAXMIN(retType, type1, type2)              \
                                                   \
inline retType max(const type1 s1, const type2 s2) \
{                                                  \
    return (s1 > s2)? s1: s2;                      \
}                                                  \
                                                   \
inline retType min(const type1 s1, const type2 s2) \
{                                                  \
    return (s1 < s2)? s1: s2;                      \
}


MAXMIN(int8_t, int8_t, int8_t)
MAXMIN(int16_t, int16_t, int16_t)

MAXMIN(int32_t, int32_t, int32_t)
MAXMIN(int64_t, int64_t, int32_t)
MAXMIN(int64_t, int32_t, int64_t)
MAXMIN(int64_t, int64_t, int64_t)


// * * * * * * * * * * * * * * * IOstream Operators  * * * * * * * * * * * * //

int readInt(Istream&);


#if defined(_WIN32)

// Windows LLP64: long is a distinct 32-bit type, matched by neither the
// int32_t nor the int64_t stream operators (on LP64 systems long is
// int64_t). Delegate to the 32-bit operators.

inline Istream& operator>>(Istream& is, long& l)
{
    int32_t i;
    is >> i;
    l = i;
    return is;
}

inline Ostream& operator<<(Ostream& os, const long l)
{
    return os << int32_t(l);
}

inline Istream& operator>>(Istream& is, unsigned long& l)
{
    uint32_t i;
    is >> i;
    l = i;
    return is;
}

inline Ostream& operator<<(Ostream& os, const unsigned long l)
{
    return os << uint32_t(l);
}

#endif


// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

} // End namespace Foam

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

#endif

// ************************************************************************* //
