/************************************************************************
 * Module
 *      Win32::MMF
 * Description
 *      Native Windows-32bit Memory Mapped File Support
 * Author
 *      Roger Lee
 *      Copyright (C) 2004. All Rights Reserved.
 *
 * $Id: MMF.xs,v 1.1 2004/02/05 15:06:03 Roger Lee Exp $
 * ---
 * $Log: MMF.xs,v $
 * Revision 1.1  2004/02/05 15:06:03  Roger Lee
 * Initial release of Win32::MMF.
 *
 ************************************************************************/
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <windows.h>
#include <memory.h>

#define MY_CXT_KEY "Win32::MMF::_guts" XS_VERSION

typedef struct {
    int    debug;
} my_cxt_t;

START_MY_CXT

MODULE = Win32::MMF		PACKAGE = Win32::MMF

BOOT:
    {
        MY_CXT_INIT;
        MY_CXT.debug = 0;
    }


void SetDebugMode(IV mode)
PREINIT:
    dMY_CXT;
CODE:
{
    MY_CXT.debug = mode;
}


IV GetDebugMode(void)
PREINIT:
    dMY_CXT;
CODE:
{
    RETVAL = MY_CXT.debug;
}
OUTPUT:
    RETVAL


IV CreateFile(char *szMapFileName)
PREINIT:
    dMY_CXT;
    HANDLE hFile = NULL;
CODE:
{
    if (strlen(szMapFileName) > 0) {
        if (MY_CXT.debug) printf("CreateFile: filename=%s\n", szMapFileName);

        hFile = CreateFile(
                    szMapFileName,
                    GENERIC_WRITE | GENERIC_READ,
                    FILE_SHARE_READ | FILE_SHARE_WRITE,
                    NULL,
                    CREATE_ALWAYS,
                    FILE_ATTRIBUTE_TEMPORARY,
                    NULL);

        if (hFile == (HANDLE)INVALID_HANDLE_VALUE)
        {
        	if (MY_CXT.debug) printf("CreateFile: Failed to create %s\n", szMapFileName);

        	XSRETURN_UNDEF;
        }
    }

    RETVAL = (long)hFile;
}
OUTPUT:
    RETVAL


IV OpenFile(char *szMapFileName)
PREINIT:
    dMY_CXT;
    HANDLE hFile = NULL;
    OFSTRUCT   of;
CODE:
{
    if (strlen(szMapFileName) > 0) {
        if (MY_CXT.debug) printf("OpenFile: filename=%s\n", szMapFileName);

        if ((hFile = (HANDLE) OpenFile (szMapFileName, &of, OF_READWRITE)) == (HANDLE)HFILE_ERROR)
        {
            if (MY_CXT.debug)
                printf("OpenFile: Failed to open %s\n", szMapFileName);

        	XSRETURN_UNDEF;
        }
    }

    RETVAL = (long)hFile;
}
OUTPUT:
    RETVAL


IV CreateFileMapping(IV szMapFileHandle, IV szMapFileSize, char *szNameSpace)
PREINIT:
    dMY_CXT;
    HANDLE hmmFile = NULL;
    HANDLE hFile = (HANDLE)0xFFFFFFFF;
CODE:
{
    if (szMapFileHandle) {
        hFile = (HANDLE) szMapFileHandle;
    }

    if (MY_CXT.debug) {
        printf( "CreateFileMapping: %s (size=%ld, namespace=%s)\n",
                szMapFileHandle ? "ext-swap" : "system-swap",
                szMapFileSize,
                strlen(szNameSpace)==0 ? "undefined" : szNameSpace);
    }

    hmmFile = CreateFileMapping(hFile,
                               NULL,
                               PAGE_READWRITE,
                               0,
                               szMapFileSize,
                               szNameSpace);

    if (!hmmFile && MY_CXT.debug) {
        printf("CreateFileMapping: Error creating file mapping\n");
        XSRETURN_UNDEF;
    }

    RETVAL = (long) hmmFile;
}
OUTPUT:
    RETVAL


IV OpenFileMapping(char *szNameSpace)
PREINIT:
    dMY_CXT;
    HANDLE hFile = NULL;
    char *ns = NULL;        // unique namespace / object-id
CODE:
{
    if (strlen(szNameSpace) > 0)
    {
        if (MY_CXT.debug) {
            printf("OpenFileMapping: namespace=%s\n", szNameSpace);
        }

        hFile = OpenFileMapping(FILE_MAP_WRITE,
                                FALSE,
                                szNameSpace);

        if (hFile == (HANDLE)INVALID_HANDLE_VALUE)
        {
        	if (MY_CXT.debug)
                printf("OpenFileMapping: invalid object/namespace %s\n", szNameSpace);

        	XSRETURN_UNDEF;
        }
    }

    RETVAL = (long) hFile;
}
OUTPUT:
    RETVAL



IV MapViewOfFile(IV szMemoryMapFileHandle, IV offset, IV size)
PREINIT:
    dMY_CXT;
    LPVOID mem;
CODE:
{
    if (!szMemoryMapFileHandle) {
        XSRETURN_UNDEF;
    }
    
    mem = MapViewOfFile((HANDLE) szMemoryMapFileHandle, FILE_MAP_WRITE, 0, offset, size);
    if (mem == NULL) {
        XSRETURN_UNDEF;
    }

    RETVAL = (long) mem;
}
OUTPUT:
    RETVAL


void UnmapViewOfFile(IV szView)
PREINIT:
    dMY_CXT;
    LPVOID mem;
CODE:
{
     if (szView) {
        mem = (LPVOID) szView;
        UnmapViewOfFile(mem);
     }
}


void CloseHandle(IV szHandle)
PREINIT:
    dMY_CXT;
CODE:
{
    if (szHandle) {
        CloseHandle((HANDLE)szHandle);
    }
}


void PokeIV(IV szView, IV value)
PREINIT:
    dMY_CXT;
CODE:
{
    if (szView) {
        *((IV *)szView) = value;
    }
}


IV PeekIV(IV szView)
PREINIT:
    dMY_CXT;
CODE:
{
     if (szView) {
        RETVAL = *((IV *)szView);
     }
}
OUTPUT:
    RETVAL


void Poke(IV szView, char *value, IV size)
PREINIT:
    dMY_CXT;
CODE:
{
     if (szView && size) {
        *((IV *)szView) = size;
        memcpy((LPVOID)(((IV *)szView)+1), value, size);
     }
}


SV *Peek(IV szView)
PREINIT:
    dMY_CXT;
    IV size;
CODE:
{
     if (szView) {
        size = *((IV *)szView);
        if (!size) {
            XSRETURN_UNDEF;
        }
        RETVAL = newSVpvn((LPVOID)(((IV *)szView)+1), size);
     }
}
OUTPUT:
    RETVAL

