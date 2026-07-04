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

#include "sigQuit.H"
#include "error.H"
#include "jobInfo.H"
#include "IOstreams.H"

// Windows has no SIGQUIT; use SIGBREAK (Ctrl-Break) instead
#ifndef SIGBREAK
    #define SIGBREAK 21
#endif

// * * * * * * * * * * * * * * Static Data Members * * * * * * * * * * * * * //

void (*Foam::sigQuit::oldHandler_)(int) = nullptr;
bool Foam::sigQuit::trapped_ = false;


// * * * * * * * * * * * * * Private Member Functions  * * * * * * * * * * * //

void Foam::sigQuit::sigHandler(int)
{
    // Reset old handling
    ::signal(SIGBREAK, oldHandler_ ? oldHandler_ : SIG_DFL);

    // Update jobInfo file
    jobInfo_.signalEnd();

    error::printStack(Perr);

    // Throw signal (to old handler)
    ::raise(SIGBREAK);
}


// * * * * * * * * * * * * * * * * Constructors  * * * * * * * * * * * * * * //

Foam::sigQuit::sigQuit()
{}


// * * * * * * * * * * * * * * * * Destructor  * * * * * * * * * * * * * * * //

Foam::sigQuit::~sigQuit()
{
    if (trapped_)
    {
        ::signal(SIGBREAK, oldHandler_ ? oldHandler_ : SIG_DFL);
        trapped_ = false;
    }
}


// * * * * * * * * * * * * * * * Member Functions  * * * * * * * * * * * * * //

void Foam::sigQuit::set(const bool)
{
    if (trapped_)
    {
        FatalErrorInFunction
            << "Cannot call sigQuit::set() more than once"
            << abort(FatalError);
    }

    oldHandler_ = ::signal(SIGBREAK, sigHandler);
    if (oldHandler_ == SIG_ERR)
    {
        oldHandler_ = nullptr;
        FatalErrorInFunction
            << "Cannot set SIGBREAK trapping"
            << abort(FatalError);
    }
    trapped_ = true;
}


// ************************************************************************* //
