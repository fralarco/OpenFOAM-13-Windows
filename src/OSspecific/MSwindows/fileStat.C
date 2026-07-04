/*---------------------------------------------------------------------------*\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Copyright (C) 2011-2025 OpenFOAM Foundation
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

\*---------------------------------------------------------------------------*/

// Native Windows implementation: no lstat (stat follows reparse points),
// no timer-based timeout, no POSIX major/minor device decomposition.

#include "fileStat.H"
#include "IOstreams.H"

#include <sys/stat.h>

// * * * * * * * * * * * * * * Static Data Members * * * * * * * * * * * * * //

const Foam::label Foam::fileStat::nVariants_ = 2;

const char* Foam::fileStat::variantExts_[] = {"gz", "orig"};


// * * * * * * * * * * * * * * * * Constructors  * * * * * * * * * * * * * * //

Foam::fileStat::fileStat()
:
    isValid_(false)
{}


Foam::fileStat::fileStat
(
    const fileName& fName,
    const bool checkVariants,
    const bool followLink,
    const unsigned int maxTime
)
{
    bool locIsValid = false;

    if (::stat(fName.c_str(), &status_) == 0)
    {
        locIsValid = true;
    }
    else if (checkVariants)
    {
        for (label i = 0; !locIsValid && i < nVariants_; ++ i)
        {
            const fileName fNameVar = fName + "." + variantExts_[i];
            if (::stat(fNameVar.c_str(), &status_) == 0)
            {
                locIsValid = true;
            }
        }
    }

    isValid_ = locIsValid;
}


Foam::fileStat::fileStat(Istream& is)
{
    is >> *this;
}


// * * * * * * * * * * * * * * * Member Functions  * * * * * * * * * * * * * //

bool Foam::fileStat::sameDevice(const fileStat& stat2) const
{
    return isValid_ && (status_.st_dev == stat2.status().st_dev);
}


bool Foam::fileStat::sameINode(const fileStat& stat2) const
{
    return isValid_ && (status_.st_ino == stat2.status().st_ino);
}


bool Foam::fileStat::sameINode(const label iNode) const
{
    return isValid_ && (status_.st_ino == ino_t(iNode));
}


// * * * * * * * * * * * * * * * Friend Operators  * * * * * * * * * * * * * //

Foam::Istream& Foam::operator>>(Istream& is, fileStat& fStat)
{
    FixedList<label, 13> stat(is);

    fStat.isValid_ = stat[0];

    fStat.status_.st_dev = stat[1];

    fStat.status_.st_ino = stat[3];
    fStat.status_.st_mode = stat[4];
    fStat.status_.st_uid = stat[5];
    fStat.status_.st_gid = stat[6];

    fStat.status_.st_rdev = stat[7];

    fStat.status_.st_size = stat[9];
    fStat.status_.st_atime = stat[10];
    fStat.status_.st_mtime = stat[11];
    fStat.status_.st_ctime = stat[12];

    // Check state of Istream
    is.check("Istream& operator>>(Istream&, fileStat&)");

    return is;
}


Foam::Ostream& Foam::operator<<(Ostream& os, const fileStat& fStat)
{
    FixedList<label, 13> stat;

    stat[0] = label(fStat.isValid_);
    stat[1] = label(fStat.status_.st_dev);
    stat[2] = 0;
    stat[3] = label(fStat.status_.st_ino);
    stat[4] = label(fStat.status_.st_mode);
    stat[5] = label(fStat.status_.st_uid);
    stat[6] = label(fStat.status_.st_gid);
    stat[7] = label(fStat.status_.st_rdev);
    stat[8] = 0;
    stat[9] = label(fStat.status_.st_size);
    stat[10] = label(fStat.status_.st_atime);
    stat[11] = label(fStat.status_.st_mtime);
    stat[12] = label(fStat.status_.st_ctime);

    return os << stat;
}


// ************************************************************************* //
