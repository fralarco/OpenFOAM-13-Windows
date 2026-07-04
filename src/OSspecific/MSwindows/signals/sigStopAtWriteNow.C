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

#include "sigStopAtWriteNow.H"
#include "sigWriteNow.H"
#include "error.H"
#include "jobInfo.H"
#include "IOstreams.H"
#include "Time.H"

// * * * * * * * * * * * * * * Static Data Members * * * * * * * * * * * * * //

namespace Foam
{

// Signal number to catch
int sigStopAtWriteNow::signal_
(
    debug::optimisationSwitch("stopAtWriteNowSignal", -1)
);

} // End namespace Foam


Foam::Time const* Foam::sigStopAtWriteNow::runTimePtr_ = nullptr;
void (*Foam::sigStopAtWriteNow::oldHandler_)(int) = nullptr;


// * * * * * * * * * * * * * Private Member Functions  * * * * * * * * * * * //

void Foam::sigStopAtWriteNow::sigHandler(int)
{
    // Reset old handling
    ::signal(signal_, oldHandler_ ? oldHandler_ : SIG_DFL);

    // Update jobInfo file
    jobInfo_.signalEnd();

    Info<< "sigStopAtWriteNow :"
        << " setting up write and stop at end of the next iteration"
        << nl << endl;
    runTimePtr_->stopAt(Time::stopAtControl::writeNow);
}


// * * * * * * * * * * * * * * * * Constructors  * * * * * * * * * * * * * * //

Foam::sigStopAtWriteNow::sigStopAtWriteNow(){}


Foam::sigStopAtWriteNow::sigStopAtWriteNow
(
    const bool verbose,
    const Time& runTime
)
{
    // Store runTime
    runTimePtr_ = &runTime;

    set(verbose);
}


// * * * * * * * * * * * * * * * * Destructor  * * * * * * * * * * * * * * * //

Foam::sigStopAtWriteNow::~sigStopAtWriteNow()
{
    // Reset old handling
    if (signal_ > 0)
    {
        ::signal(signal_, oldHandler_ ? oldHandler_ : SIG_DFL);
    }
}


// * * * * * * * * * * * * * * * Member Functions  * * * * * * * * * * * * * //

void Foam::sigStopAtWriteNow::set(const bool verbose)
{
    if (signal_ >= 0)
    {
        // Check that the signal is different from the writeNowSignal
        if (sigWriteNow::signal_ == signal_)
        {
            FatalErrorInFunction
                << "stopAtWriteNowSignal : " << signal_
                << " cannot be the same as the writeNowSignal."
                << " Please change this in the etc/controlDict."
                << exit(FatalError);
        }

        void (*prev)(int) = ::signal(signal_, sigHandler);
        if (prev == SIG_ERR)
        {
            WarningInFunction
                << "Cannot set signal " << signal_ << " trapping;"
                << " unsupported signal number on this platform" << endl;
            signal_ = -1;
            return;
        }
        oldHandler_ = prev;

        if (verbose)
        {
            Info<< "sigStopAtWriteNow :"
                << " Enabling writing and stopping upon signal " << signal_
                << endl;
        }
    }
}


bool Foam::sigStopAtWriteNow::active() const
{
    return signal_ > 0;
}


// ************************************************************************* //
