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

#include "sigFpe.H"
#include "error.H"
#include "jobInfo.H"
#include "OSspecific.H"
#include "IOstreams.H"

#include <float.h>
#include <limits>

// * * * * * * * * * * * * * * Static Data Members * * * * * * * * * * * * * //

void (*Foam::sigFpe::oldHandler_)(int) = nullptr;
bool Foam::sigFpe::trapped_ = false;
unsigned int Foam::sigFpe::oldFpControl_ = 0;

void Foam::sigFpe::fillNan(UList<scalar>& lst)
{
    lst = std::numeric_limits<scalar>::signaling_NaN();
}

bool Foam::sigFpe::mallocNanActive_ = false;


// * * * * * * * * * * * * * Private Member Functions  * * * * * * * * * * * //

void Foam::sigFpe::sigHandler(int)
{
    // Reset old handling and mask FP exceptions again
    ::signal(SIGFPE, oldHandler_ ? oldHandler_ : SIG_DFL);

    unsigned int dummy;
    _controlfp_s(&dummy, oldFpControl_, _MCW_EM);

    // Update jobInfo file
    jobInfo_.signalEnd();

    error::printStack(Perr);

    // Throw signal (to old handler)
    ::raise(SIGFPE);
}


// * * * * * * * * * * * * * * * * Constructors  * * * * * * * * * * * * * * //

Foam::sigFpe::sigFpe()
{}


// * * * * * * * * * * * * * * * * Destructor  * * * * * * * * * * * * * * * //

Foam::sigFpe::~sigFpe()
{
    if (env("FOAM_SIGFPE") && trapped_)
    {
        ::signal(SIGFPE, oldHandler_ ? oldHandler_ : SIG_DFL);

        unsigned int dummy;
        _controlfp_s(&dummy, oldFpControl_, _MCW_EM);

        trapped_ = false;
    }
}


// * * * * * * * * * * * * * * * Member Functions  * * * * * * * * * * * * * //

void Foam::sigFpe::set(const bool verbose)
{
    if (trapped_)
    {
        FatalErrorInFunction
            << "Cannot call sigFpe::set() more than once"
            << abort(FatalError);
    }

    if (env("FOAM_SIGFPE"))
    {
        // Save the current control word and unmask divide-by-zero,
        // invalid and overflow exceptions; the UCRT raises SIGFPE for
        // unmasked exceptions
        _controlfp_s(&oldFpControl_, 0, 0);

        unsigned int dummy;
        _controlfp_s
        (
            &dummy,
            oldFpControl_ & ~(_EM_ZERODIVIDE | _EM_INVALID | _EM_OVERFLOW),
            _MCW_EM
        );

        oldHandler_ = ::signal(SIGFPE, sigHandler);
        if (oldHandler_ == SIG_ERR)
        {
            oldHandler_ = nullptr;
            FatalErrorInFunction
                << "Cannot set SIGFPE trapping"
                << abort(FatalError);
        }
        trapped_ = true;

        if (verbose)
        {
            Info<< "sigFpe : Enabling floating point exception trapping"
                << " (FOAM_SIGFPE)." << endl;
        }
    }

    if (env("FOAM_SETNAN"))
    {
        if (verbose)
        {
            Info<< "SetNaN : Initialise allocated memory to NaN"
                << " - not supported on this platform" << endl;
        }
    }
}


// ************************************************************************* //
