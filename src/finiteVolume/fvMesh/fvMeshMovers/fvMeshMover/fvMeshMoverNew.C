/*---------------------------------------------------------------------------*\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Copyright (C) 2021-2024 OpenFOAM Foundation
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

#include "none_fvMeshMover.H"

// * * * * * * * * * * * * * * * * Selectors * * * * * * * * * * * * * * * * //

Foam::autoPtr<Foam::fvMeshMover> Foam::fvMeshMover::New(fvMesh& mesh)
{
    typeIOobject<IOdictionary> dictHeader
    (
        IOobject
        (
            "dynamicMeshDict",
            mesh.time().constant(),
            mesh,
            IOobject::READ_IF_PRESENT,
            IOobject::NO_WRITE,
            false
        )
    );

    if (dictHeader.headerOk())
    {
        IOdictionary dict(dictHeader);

        if (dict.found("mover"))
        {
            const dictionary& moverDict = dict.subDict("mover");

            const word fvMeshMoverTypeName(moverDict.lookup("type"));

            Info<< "Selecting fvMeshMover " << fvMeshMoverTypeName << endl;

            libs.open
            (
                moverDict,
                "libs",
                fvMeshConstructorTablePtr_
            );

            if (!fvMeshConstructorTablePtr_)
            {
                FatalIOErrorInFunction(dict)
                    << "fvMeshMovers table is empty"
                    << exit(FatalIOError);
            }

            fvMeshConstructorTable::iterator cstrIter =
                fvMeshConstructorTablePtr_->find(fvMeshMoverTypeName);

#if defined(_WIN32)
            // Windows PE/COFF does not pull a registration-only fvMeshMover
            // plugin (libmotionSolver_fvMeshMover, ...) into the process through
            // the link closure of the library named in the case 'libs' entry:
            // e.g. librigidBodyMeshMotion links -lmotionSolver_fvMeshMover but
            // references no symbol from it, so the import is dropped and the
            // type never registers. Load the plugin on demand by the standard
            // lib<type>_fvMeshMover naming and re-look-up, exactly as the
            // decomposition-method plugins are loaded. POSIX pulls it in via the
            // dependent library, so this path is Windows-only.
            if (cstrIter == fvMeshConstructorTablePtr_->end())
            {
                libs.open
                (
                    "lib" + fvMeshMoverTypeName + "_fvMeshMover.so",
                    false
                );
                cstrIter =
                    fvMeshConstructorTablePtr_->find(fvMeshMoverTypeName);
            }
#endif

            if (cstrIter == fvMeshConstructorTablePtr_->end())
            {
                FatalIOErrorInFunction(dict)
                    << "Unknown fvMeshMover type "
                    << fvMeshMoverTypeName << nl << nl
                    << "Valid fvMeshMovers are :" << endl
                    << fvMeshConstructorTablePtr_->sortedToc()
                    << exit(FatalIOError);
            }

            return autoPtr<fvMeshMover>(cstrIter()(mesh, moverDict));
        }
    }

    return autoPtr<fvMeshMover>(new fvMeshMovers::none(mesh));
}


// ************************************************************************* //
