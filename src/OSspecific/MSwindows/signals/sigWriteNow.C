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

#include "sigWriteNow.H"
#include "error.H"
#include "jobInfo.H"
#include "IOstreams.H"
#include "Time.H"

// * * * * * * * * * * * * * * Static Data Members * * * * * * * * * * * * * //

namespace Foam
{

// Signal number to catch
int sigWriteNow::signal_
(
    debug::optimisationSwitch("writeNowSignal", -1)
);

} // End namespace Foam


Foam::Time* Foam::sigWriteNow::runTimePtr_ = nullptr;
void (*Foam::sigWriteNow::oldHandler_)(int) = nullptr;


// * * * * * * * * * * * * * Private Member Functions  * * * * * * * * * * * //

void Foam::sigWriteNow::sigHandler(int)
{
    Info<< "sigWriteNow :"
        << " setting up write at end of the next iteration" << nl << endl;
    runTimePtr_->writeOnce();
}


// * * * * * * * * * * * * * * * * Constructors  * * * * * * * * * * * * * * //

Foam::sigWriteNow::sigWriteNow()
{}


Foam::sigWriteNow::sigWriteNow(const bool verbose, Time& runTime)
{
    // Store runTime
    runTimePtr_ = &runTime;

    set(verbose);
}


// * * * * * * * * * * * * * * * * Destructor  * * * * * * * * * * * * * * * //

Foam::sigWriteNow::~sigWriteNow()
{
    // Reset old handling
    if (signal_ > 0)
    {
        ::signal(signal_, oldHandler_ ? oldHandler_ : SIG_DFL);
    }
}


// * * * * * * * * * * * * * * * Member Functions  * * * * * * * * * * * * * //

void Foam::sigWriteNow::set(const bool verbose)
{
    if (signal_ >= 0)
    {
        void (*prev)(int) = ::signal(signal_, sigHandler);
        if (prev == SIG_ERR)
        {
            // The UCRT supports only a small fixed set of signal numbers;
            // report rather than abort so that Linux-oriented settings
            // remain usable
            WarningInFunction
                << "Cannot set signal " << signal_ << " trapping;"
                << " unsupported signal number on this platform" << endl;
            signal_ = -1;
            return;
        }
        oldHandler_ = prev;

        if (verbose)
        {
            Info<< "sigWriteNow :"
                << " Enabling writing upon signal " << signal_
                << endl;
        }
    }
}


bool Foam::sigWriteNow::active() const
{
    return signal_ > 0;
}


// ************************************************************************* //
