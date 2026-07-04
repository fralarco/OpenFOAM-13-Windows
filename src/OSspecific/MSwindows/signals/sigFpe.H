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

Class
    Foam::sigFpe

Description
    Set up trapping for floating point exceptions (signal FPE) on native
    Windows (MinGW-w64/UCRT), using _controlfp and signal(SIGFPE).

    Controlled by the env var FOAM_SIGFPE. FOAM_SETNAN (malloc NaN
    initialisation) is not supported on this platform.

SourceFiles
    sigFpe.C

\*---------------------------------------------------------------------------*/

#ifndef sigFpe_H
#define sigFpe_H

#include <signal.h>

#include "UList.H"

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

namespace Foam
{

/*---------------------------------------------------------------------------*\
                           Class sigFpe Declaration
\*---------------------------------------------------------------------------*/

class sigFpe
{
    // Private Data

        //- Saved old signal handler
        static void (*oldHandler_)(int);

        //- Has the handler been installed?
        static bool trapped_;

        //- Saved floating point control word
        static unsigned int oldFpControl_;


    // Static Data Members

        //- Handler for caught signals
        static void sigHandler(int);


public:


    // Constructors

        //- Construct null
        sigFpe();


    //- Destructor
    ~sigFpe();


    // Member Functions

        //- Activate SIGFPE signal handler when FOAM_SIGFPE is %set
        void set(const bool verbose);

        //- Flag to indicate mallocNan is enabled
        static bool mallocNanActive_;

        //- Fill block of data with NaN
        static void fillNan(UList<scalar>&);
};


// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

} // End namespace Foam

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

#endif

// ************************************************************************* //
