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

#include "sigSegv.H"
#include "error.H"
#include "jobInfo.H"
#include "IOstreams.H"

// * * * * * * * * * * * * * * Static Data Members * * * * * * * * * * * * * //

void (*Foam::sigSegv::oldHandler_)(int) = nullptr;
bool Foam::sigSegv::trapped_ = false;


// * * * * * * * * * * * * * Private Member Functions  * * * * * * * * * * * //

void Foam::sigSegv::sigHandler(int)
{
    // Reset old handling
    ::signal(SIGSEGV, oldHandler_ ? oldHandler_ : SIG_DFL);

    // Update jobInfo file
    jobInfo_.signalEnd();

    error::printStack(Perr);

    // Throw signal (to old handler)
    ::raise(SIGSEGV);
}


// * * * * * * * * * * * * * * * * Constructors  * * * * * * * * * * * * * * //

Foam::sigSegv::sigSegv()
{}


// * * * * * * * * * * * * * * * * Destructor  * * * * * * * * * * * * * * * //

Foam::sigSegv::~sigSegv()
{
    if (trapped_)
    {
        ::signal(SIGSEGV, oldHandler_ ? oldHandler_ : SIG_DFL);
        trapped_ = false;
    }
}


// * * * * * * * * * * * * * * * Member Functions  * * * * * * * * * * * * * //

void Foam::sigSegv::set(const bool)
{
    if (trapped_)
    {
        FatalErrorInFunction
            << "Cannot call sigSegv::set() more than once"
            << abort(FatalError);
    }

    oldHandler_ = ::signal(SIGSEGV, sigHandler);
    if (oldHandler_ == SIG_ERR)
    {
        oldHandler_ = nullptr;
        FatalErrorInFunction
            << "Cannot set SIGSEGV trapping"
            << abort(FatalError);
    }
    trapped_ = true;
}


// ************************************************************************* //
