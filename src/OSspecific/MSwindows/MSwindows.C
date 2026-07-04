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

// OS-specific functions for native Windows (MinGW-w64/UCRT).
// Part of the FoamStudio OpenFOAM 13 Windows port; independently derived
// from the upstream POSIX implementation.

#include "OSspecific.H"
#include "MSwindows.H"
#include "foamVersion.H"
#include "fileName.H"
#include "fileStat.H"
#include "DynamicList.H"
#include "HashSet.H"
#include "IOstreams.H"
#include "Pstream.H"

#include <fstream>
#include <cstdlib>
#include <cctype>
#include <cstring>

#include <stdio.h>
#include <io.h>
#include <direct.h>
#include <dirent.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <psapi.h>
#include <tlhelp32.h>

// windows.h macro pollution
#undef ERROR
#undef interface
#undef small
#undef near
#undef far

// * * * * * * * * * * * * * * Static Data Members * * * * * * * * * * * * * //

namespace Foam
{
    defineTypeNameAndDebug(MSwindows, 0);
}


// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //

pid_t Foam::pid()
{
    return ::_getpid();
}


pid_t Foam::ppid()
{
    // Windows has no parent-pid concept in the CRT; walk the process
    // snapshot for the creator of this process
    pid_t parent = 0;

    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot != INVALID_HANDLE_VALUE)
    {
        PROCESSENTRY32 entry;
        entry.dwSize = sizeof(entry);
        const DWORD self = GetCurrentProcessId();

        if (Process32First(snapshot, &entry))
        {
            do
            {
                if (entry.th32ProcessID == self)
                {
                    parent = pid_t(entry.th32ParentProcessID);
                    break;
                }
            } while (Process32Next(snapshot, &entry));
        }

        CloseHandle(snapshot);
    }

    return parent;
}


pid_t Foam::pgid()
{
    // No process-group concept on Windows
    return 0;
}


bool Foam::env(const word& envName)
{
    return ::getenv(envName.c_str()) != nullptr;
}


Foam::string Foam::getEnv(const word& envName)
{
    char* env = ::getenv(envName.c_str());

    if (env)
    {
        return string(env);
    }
    else
    {
        // Return null-constructed string rather than string::null
        // to avoid cyclic dependencies in the construction of globals
        return string();
    }
}


bool Foam::setEnv
(
    const word& envName,
    const std::string& value,
    const bool overwrite
)
{
    if (!overwrite && ::getenv(envName.c_str()))
    {
        return true;
    }

    return ::_putenv_s(envName.c_str(), value.c_str()) == 0;
}


Foam::string Foam::hostName(bool full)
{
    char buf[256];
    DWORD len = sizeof(buf);

    const COMPUTER_NAME_FORMAT format =
        full ? ComputerNameDnsFullyQualified : ComputerNameDnsHostname;

    if (GetComputerNameExA(format, buf, &len))
    {
        return string(buf);
    }

    return string();
}


Foam::string Foam::domainName()
{
    char buf[256];
    DWORD len = sizeof(buf);

    if (GetComputerNameExA(ComputerNameDnsDomain, buf, &len) && len)
    {
        return string(buf);
    }

    return string::null;
}


Foam::string Foam::userName()
{
    char* env = ::getenv("USERNAME");
    if (env != nullptr)
    {
        return string(env);
    }

    char buf[256];
    DWORD len = sizeof(buf);
    if (GetUserNameA(buf, &len))
    {
        return string(buf);
    }

    return string::null;
}


bool Foam::isAdministrator()
{
    BOOL isMember = FALSE;
    PSID adminGroup = nullptr;

    SID_IDENTIFIER_AUTHORITY ntAuthority = SECURITY_NT_AUTHORITY;
    if
    (
        AllocateAndInitializeSid
        (
            &ntAuthority,
            2,
            SECURITY_BUILTIN_DOMAIN_RID,
            DOMAIN_ALIAS_RID_ADMINS,
            0, 0, 0, 0, 0, 0,
            &adminGroup
        )
    )
    {
        if (!CheckTokenMembership(nullptr, adminGroup, &isMember))
        {
            isMember = FALSE;
        }
        FreeSid(adminGroup);
    }

    return isMember == TRUE;
}


Foam::fileName Foam::home()
{
    char* env = ::getenv("HOME");

    if (env != nullptr)
    {
        return fileName(string(env));
    }

    env = ::getenv("USERPROFILE");
    if (env != nullptr)
    {
        string profile(env);
        string::stripInvalid<fileName>(profile);
        fileName profileDir(profile);
        profileDir.replaceAll("\\", "/");
        return profileDir;
    }

    return fileName::null;
}


Foam::fileName Foam::home(const string& userName)
{
    // Windows provides no getpwnam; only the current user's home
    // directory can be determined
    if (userName.empty() || userName == Foam::userName())
    {
        return home();
    }

    return fileName::null;
}


Foam::fileName Foam::cwd()
{
    label pathLengthLimit = MSwindows::pathLengthChunk;
    List<char> path(pathLengthLimit);

    // Resize path if getcwd fails with an ERANGE error
    while(pathLengthLimit == path.size())
    {
        if (::_getcwd(path.data(), path.size()))
        {
            string cwdPath(path.data());
            cwdPath.replaceAll("\\", "/");
            return fileName(cwdPath);
        }
        else if(errno == ERANGE)
        {
            // Increment path length up to the pathLengthMax limit
            if
            (
                (pathLengthLimit += MSwindows::pathLengthChunk)
             >= MSwindows::pathLengthMax
            )
            {
                FatalErrorInFunction
                    << "Attempt to increase path length beyond limit of "
                    << MSwindows::pathLengthMax
                    << exit(FatalError);
            }

            path.setSize(pathLengthLimit);
        }
        else
        {
            break;
        }
    }

    FatalErrorInFunction
        << "Couldn't get the current working directory"
        << exit(FatalError);

    return fileName::null;
}


bool Foam::chDir(const fileName& dir)
{
    return ::_chdir(dir.c_str()) == 0;
}


bool Foam::mkDir(const fileName& filePath, mode_t mode)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : filePath:" << filePath << " mode:" << mode
            << endl;
        if ((MSwindows::debug & 2) && !Pstream::master())
        {
            error::printStack(Pout);
        }
    }

    // Empty names are meaningless
    if (filePath.empty())
    {
        return false;
    }

    // The mode argument cannot be honoured on Windows
    if (::_mkdir(filePath.c_str()) == 0)
    {
        return true;
    }
    else
    {
        switch (errno)
        {
            case EEXIST:
            {
                // Directory already exists so simply return true
                return true;
            }

            case ENOENT:
            {
                // Part of the path does not exist so try to create it
                if (filePath.path().size() && mkDir(filePath.path(), mode))
                {
                    return mkDir(filePath, mode);
                }
                else
                {
                    FatalErrorInFunction
                        << "Couldn't create directory " << filePath
                        << exit(FatalError);

                    return false;
                }
            }

            default:
            {
                FatalErrorInFunction
                    << "Couldn't create directory " << filePath
                    << exit(FatalError);

                return false;
            }
        }
    }
}


bool Foam::chMod(const fileName& name, const mode_t m)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : name:" << name << endl;
    }
    return ::chmod(name.c_str(), m) == 0;
}


mode_t Foam::mode
(
    const fileName& name,
    const bool checkVariants,
    const bool followLink
)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : name:" << name << endl;
        if ((MSwindows::debug & 2) && !Pstream::master())
        {
            error::printStack(Pout);
        }
    }
    fileStat fileStatus(name, checkVariants, followLink);
    if (fileStatus.isValid())
    {
        return fileStatus.status().st_mode;
    }
    else
    {
        return 0;
    }
}


Foam::fileType Foam::type
(
    const fileName& name,
    const bool checkVariants,
    const bool followLink
)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : name:" << name << endl;
    }
    mode_t m = mode(name, checkVariants, followLink);

    if (S_ISREG(m))
    {
        return fileType::file;
    }
    #ifdef S_ISLNK
    else if (S_ISLNK(m))
    {
        return fileType::link;
    }
    #endif
    else if (S_ISDIR(m))
    {
        return fileType::directory;
    }
    else
    {
        return fileType::undefined;
    }
}


bool Foam::exists
(
    const fileName& name,
    const bool checkVariants,
    const bool followLink
)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : name:" << name << " checkVariants:"
            << bool(checkVariants) << " followLink:" << followLink << endl;
        if ((MSwindows::debug & 2) && !Pstream::master())
        {
            error::printStack(Pout);
        }
    }
    return mode(name, checkVariants, followLink);
}


bool Foam::isDir(const fileName& name, const bool followLink)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : name:" << name << " followLink:"
            << followLink << endl;
        if ((MSwindows::debug & 2) && !Pstream::master())
        {
            error::printStack(Pout);
        }
    }
    return S_ISDIR(mode(name, false, followLink));
}


bool Foam::isFile
(
    const fileName& name,
    const bool checkVariants,
    const bool followLink
)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : name:" << name << " checkVariants:"
            << bool(checkVariants) << " followLink:" << followLink << endl;
        if ((MSwindows::debug & 2) && !Pstream::master())
        {
            error::printStack(Pout);
        }
    }

    return S_ISREG(mode(name, checkVariants, followLink));
}


off_t Foam::fileSize
(
    const fileName& name,
    const bool checkVariants,
    const bool followLink
)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : name:" << name << " checkVariants:"
            << bool(checkVariants) << " followLink:" << followLink << endl;
        if ((MSwindows::debug & 2) && !Pstream::master())
        {
            error::printStack(Pout);
        }
    }
    fileStat fileStatus(name, checkVariants, followLink);
    if (fileStatus.isValid())
    {
        return fileStatus.status().st_size;
    }
    else
    {
        return -1;
    }
}


time_t Foam::lastModified
(
    const fileName& name,
    const bool checkVariants,
    const bool followLink
)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : name:" << name << " checkVariants:"
            << bool(checkVariants) << " followLink:" << followLink << endl;
        if ((MSwindows::debug & 2) && !Pstream::master())
        {
            error::printStack(Pout);
        }
    }
    fileStat fileStatus(name, checkVariants, followLink);
    if (fileStatus.isValid())
    {
        return fileStatus.status().st_mtime;
    }
    else
    {
        return 0;
    }
}


double Foam::highResLastModified
(
    const fileName& name,
    const bool checkVariants,
    const bool followLink
)
{
    // No sub-second resolution in the MinGW stat structure
    return double(lastModified(name, checkVariants, followLink));
}


Foam::fileNameList Foam::readDir
(
    const fileName& directory,
    const fileType type,
    const bool filterVariants,
    const bool followLink
)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : reading directory " << directory << endl;
        if ((MSwindows::debug & 2) && !Pstream::master())
        {
            error::printStack(Pout);
        }
    }

    // Create empty set of file names
    HashSet<fileName> dirEntries;

    // Pointers to the directory entries
    DIR *source;
    struct dirent *list;

    // Attempt to open directory and set the structure pointer
    if ((source = ::opendir(directory.c_str())) == nullptr)
    {
        if (MSwindows::debug)
        {
            InfoInFunction
                << "cannot open directory " << directory << endl;
        }
    }
    else
    {
        // Read and parse all the entries in the directory
        while ((list = ::readdir(source)) != nullptr)
        {
            fileName fName(list->d_name);

            // Ignore files beginning with ., i.e. '.', '..' and '.*'
            if (fName.size() && fName[0] != '.')
            {
                word fExt = fName.ext();

                if
                (
                    (type == fileType::directory)
                 ||
                    (
                        type == fileType::file
                     && fName[fName.size()-1] != '~'
                     && fExt != "bak"
                     && fExt != "BAK"
                     && fExt != "old"
                     && fExt != "save"
                    )
                )
                {
                    if ((directory/fName).type(false, followLink) == type)
                    {
                        bool filtered = false;

                        if (filterVariants)
                        {
                            for (label i = 0; i < fileStat::nVariants_; ++ i)
                            {
                                if (fExt == fileStat::variantExts_[i])
                                {
                                    dirEntries.insert(fName.lessExt());
                                    filtered = true;
                                    break;
                                }
                            }
                        }

                        if (!filtered)
                        {
                            dirEntries.insert(fName);
                        }
                    }
                }
            }
        }

        ::closedir(source);
    }

    return dirEntries.toc();
}


bool Foam::cp(const fileName& src, const fileName& dest, const bool followLink)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : src:" << src << " dest:" << dest << endl;
    }
    // Make sure source exists.
    if (!exists(src))
    {
        return false;
    }

    const fileType srcType = src.type(false, followLink);

    fileName destFile(dest);

    // Check type of source file.
    if (srcType == fileType::file)
    {
        // If dest is a directory, create the destination file name.
        if (destFile.type() == fileType::directory)
        {
            destFile = destFile/src.name();
        }

        // Make sure the destination directory exists.
        if (!isDir(destFile.path()) && !mkDir(destFile.path()))
        {
            return false;
        }

        // Open and check streams. Binary mode to preserve exact content.
        std::ifstream srcStream(src.c_str(), std::ios::binary);
        if (!srcStream)
        {
            return false;
        }

        std::ofstream destStream(destFile.c_str(), std::ios::binary);
        if (!destStream)
        {
            return false;
        }

        // Copy character data.
        destStream << srcStream.rdbuf();

        // Final check.
        if (!destStream)
        {
            return false;
        }
    }
    else if (srcType == fileType::link)
    {
        // If dest is a directory, create the destination file name.
        if (destFile.type() == fileType::directory)
        {
            destFile = destFile/src.name();
        }

        // Make sure the destination directory exists.
        if (!isDir(destFile.path()) && !mkDir(destFile.path()))
        {
            return false;
        }

        ln(src, destFile);
    }
    else if (srcType == fileType::directory)
    {
        // If dest is a directory, create the destination file name.
        if (destFile.type() == fileType::directory)
        {
            destFile = destFile/src.component(src.components().size() -1);
        }

        // Make sure the destination directory exists.
        if (!isDir(destFile) && !mkDir(destFile))
        {
            return false;
        }

        char* realSrcPath = ::_fullpath(nullptr, src.c_str(), 0);
        char* realDestPath = ::_fullpath(nullptr, destFile.c_str(), 0);
        const bool samePath =
            realSrcPath && realDestPath
         && ::_stricmp(realSrcPath, realDestPath) == 0;

        if (MSwindows::debug && samePath)
        {
            InfoInFunction
                << "Attempt to copy " << realSrcPath << " to itself" << endl;
        }

        if (realSrcPath)
        {
            free(realSrcPath);
        }

        if (realDestPath)
        {
            free(realDestPath);
        }

        // Do not copy over self when src is actually a link to dest
        if (samePath)
        {
            return false;
        }

        // Copy files
        fileNameList contents = readDir(src, fileType::file, false, followLink);
        forAll(contents, i)
        {
            if (MSwindows::debug)
            {
                InfoInFunction
                    << "Copying : " << src/contents[i]
                    << " to " << destFile/contents[i] << endl;
            }

            // File to file.
            cp(src/contents[i], destFile/contents[i], followLink);
        }

        // Copy sub directories.
        fileNameList subdirs = readDir
        (
            src,
            fileType::directory,
            false,
            followLink
        );

        forAll(subdirs, i)
        {
            if (MSwindows::debug)
            {
                InfoInFunction
                    << "Copying : " << src/subdirs[i]
                    << " to " << destFile << endl;
            }

            // Dir to Dir.
            cp(src/subdirs[i], destFile, followLink);
        }
    }

    return true;
}


bool Foam::ln(const fileName& src, const fileName& dst)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME
            << " : Create softlink from : " << src << " to " << dst << endl;
    }

    if (exists(dst))
    {
        WarningInFunction
            << "destination " << dst << " already exists. Not linking."
            << endl;
        return false;
    }

    if (src.isAbsolute() && !exists(src))
    {
        WarningInFunction
            << "source " << src << " does not exist." << endl;
        return false;
    }

    // Requires Developer Mode or SeCreateSymbolicLinkPrivilege
    DWORD flags = SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE;
    if (isDir(src))
    {
        flags |= SYMBOLIC_LINK_FLAG_DIRECTORY;
    }

    if (CreateSymbolicLinkA(dst.c_str(), src.c_str(), flags))
    {
        return true;
    }
    else
    {
        WarningInFunction
            << "symlink from " << src << " to " << dst << " failed." << endl;
        return false;
    }
}


bool Foam::mv(const fileName& src, const fileName& dst, const bool followLink)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : Move : " << src << " to " << dst << endl;
    }

    // MoveFileEx with replace to obtain POSIX rename overwrite semantics
    if
    (
        dst.type() == fileType::directory
     && src.type(false, followLink) != fileType::directory
    )
    {
        const fileName dstName(dst/src.name());

        return MoveFileExA
        (
            src.c_str(),
            dstName.c_str(),
            MOVEFILE_REPLACE_EXISTING | MOVEFILE_COPY_ALLOWED
        ) != 0;
    }
    else
    {
        return MoveFileExA
        (
            src.c_str(),
            dst.c_str(),
            MOVEFILE_REPLACE_EXISTING | MOVEFILE_COPY_ALLOWED
        ) != 0;
    }
}


bool Foam::mvBak(const fileName& src, const std::string& ext)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME
            << " : moving : " << src << " to extension " << ext << endl;
    }

    if (exists(src, false, false))
    {
        const int maxIndex = 99;
        char index[3];

        for (int n = 0; n <= maxIndex; n++)
        {
            fileName dstName(src + "." + ext);
            if (n)
            {
                sprintf(index, "%02d", n);
                dstName += index;
            }

            // Avoid overwriting existing files, except for the last
            // possible index where we have no choice
            if (!exists(dstName, false, false) || n == maxIndex)
            {
                return mv(src, dstName);
            }

        }
    }

    // Fall-through: nothing to do
    return false;
}


bool Foam::rm(const fileName& file)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : Removing : " << file << endl;
    }

    // Try returning plain file name; if not there, try variants
    if (::remove(file.c_str()) == 0)
    {
        return true;
    }

    for (label i = 0; i < fileStat::nVariants_; ++ i)
    {
        const fileName fileVar = file + "." + fileStat::variantExts_[i];
        if (::remove(string(fileVar).c_str()) == 0)
        {
            return true;
        }
    }

    return false;
}


bool Foam::rmDir(const fileName& directory)
{
    if (MSwindows::debug)
    {
        Pout<< FUNCTION_NAME << " : removing directory " << directory << endl;
    }

    // Pointers to the directory entries
    DIR *source;
    struct dirent *list;

    // Attempt to open directory and set the structure pointer
    if ((source = ::opendir(directory.c_str())) == nullptr)
    {
        WarningInFunction
            << "cannot open directory " << directory << endl;

        return false;
    }
    else
    {
        // Read and parse all the entries in the directory
        while ((list = ::readdir(source)) != nullptr)
        {
            fileName fName(list->d_name);

            if (fName != "." && fName != "..")
            {
                fileName path = directory/fName;

                if (path.type(false, false) == fileType::directory)
                {
                    if (!rmDir(path))
                    {
                        WarningInFunction
                            << "failed to remove directory " << fName
                            << " while removing directory " << directory
                            << endl;

                        ::closedir(source);

                        return false;
                    }
                }
                else
                {
                    if (!rm(path))
                    {
                        WarningInFunction
                            << "failed to remove file " << fName
                            << " while removing directory " << directory
                            << endl;

                        ::closedir(source);

                        return false;
                    }
                }
            }

        }

        ::closedir(source);

        if (::_rmdir(directory.c_str()) != 0)
        {
            WarningInFunction
                << "failed to remove directory " << directory << endl;

            return false;
        }

        return true;
    }
}


unsigned int Foam::sleep(const unsigned int s)
{
    ::Sleep(DWORD(s)*1000);
    return 0;
}


void Foam::fdClose(const int fd)
{
    if (::_close(fd) != 0)
    {
        FatalErrorInFunction
            << "close error on " << fd << endl
            << abort(FatalError);
    }
}


bool Foam::ping
(
    const string& destName,
    const label destPort,
    const label timeOut
)
{
    // Not implemented on native Windows (would require winsock
    // initialisation); only used for legacy rsh/ssh host checks
    WarningInFunction
        << "ping not implemented on this platform" << endl;

    return false;
}


bool Foam::ping(const string& hostname, const label timeOut)
{
    return ping(hostname, 222, timeOut) || ping(hostname, 22, timeOut);
}


int Foam::system(const std::string& command)
{
    return ::system(command.c_str());
}


void* Foam::dlOpen(const fileName& lib, const bool check)
{
    if (MSwindows::debug)
    {
        std::cout<< "dlOpen(const fileName&)"
            << " : LoadLibrary of " << lib << std::endl;
    }

    // Map Linux-style library names (libXXX.so) used in dictionaries and
    // upstream configuration to Windows DLL names
    fileName libName(lib);
    if (libName.hasExt("so"))
    {
        libName = libName.lessExt() + ".dll";
    }

    void* handle =
        reinterpret_cast<void*>(LoadLibraryA(libName.c_str()));

    if (!handle && check)
    {
        WarningInFunction
            << "LoadLibrary error " << GetLastError()
            << " for library " << libName
            << endl;
    }

    if (MSwindows::debug)
    {
        std::cout
            << "dlOpen(const fileName&)"
            << " : LoadLibrary of " << libName
            << " handle " << handle << std::endl;
    }

    return handle;
}


bool Foam::dlClose(void* handle)
{
    if (MSwindows::debug)
    {
        std::cout
            << "dlClose(void*)"
            << " : FreeLibrary of handle " << handle << std::endl;
    }
    return FreeLibrary(reinterpret_cast<HMODULE>(handle)) != 0;
}


void* Foam::dlSym(void* handle, const std::string& symbol)
{
    if (MSwindows::debug)
    {
        std::cout
            << "dlSym(void*, const std::string&)"
            << " : GetProcAddress of " << symbol << std::endl;
    }

    // Get address of symbol
    void* fun =
        reinterpret_cast<void*>
        (
            GetProcAddress(reinterpret_cast<HMODULE>(handle), symbol.c_str())
        );

    if (!fun)
    {
        WarningInFunction
            << "Cannot lookup symbol " << symbol
            << " : error " << GetLastError()
            << endl;
    }

    return fun;
}


bool Foam::dlSymFound(void* handle, const std::string& symbol)
{
    if (handle && !symbol.empty())
    {
        if (MSwindows::debug)
        {
            std::cout
                << "dlSymFound(void*, const std::string&)"
                << " : GetProcAddress of " << symbol << std::endl;
        }

        return
            GetProcAddress
            (
                reinterpret_cast<HMODULE>(handle),
                symbol.c_str()
            ) != nullptr;
    }
    else
    {
        return false;
    }
}


Foam::fileNameList Foam::dlLoaded()
{
    DynamicList<fileName> libs;

    HMODULE modules[1024];
    DWORD needed = 0;

    if
    (
        EnumProcessModules
        (
            GetCurrentProcess(),
            modules,
            sizeof(modules),
            &needed
        )
    )
    {
        const DWORD n = needed/sizeof(HMODULE);

        for (DWORD i = 0; i < n && i < 1024; i++)
        {
            char path[MAX_PATH];
            if (GetModuleFileNameA(modules[i], path, sizeof(path)))
            {
                string libPath(path);
                libPath.replaceAll("\\", "/");
                libs.append(fileName(libPath));
            }
        }
    }

    if (MSwindows::debug)
    {
        std::cout
            << "dlLoaded()"
            << " : determined loaded libraries :" << libs.size() << std::endl;
    }

    return libs;
}


// ************************************************************************* //
