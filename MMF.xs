/************************************************************************
 * Module
 *		Win32::MMF
 * Description
 *		Native Windows-32bit Memory Mapped File Support
 * Author
 *		Roger Lee
 *		Copyright (C) 2004. All Rights Reserved.
 *
 * $Id: MMF.xs,v 1.2 2004/02/06 15:45:58 Roger Lee Exp $
 * ---
 * $Log: MMF.xs,v $
 * Revision 1.2  2004/02/06 15:45:58  Roger Lee
 * Removed mmf_* prefix from function names, added Windows semaphore support.
 *
 * Revision 1.1  2004/02/05 15:06:03  Roger Lee
 * Initial release of Win32::MMF.
 *
 ************************************************************************/
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <windows.h>
#include <memory.h>
#include "MMF.h"

#define MY_CXT_KEY "Win32::MMF::_guts" XS_VERSION

typedef struct {
	int    debug;
} my_cxt_t;

START_MY_CXT


static void __dumpheap(MMF_DESCRIPTOR *mmf)
{
	MMF_MAP *m;
	MMF_VAR *v;
	unsigned blks_used = 0, blks_free = 0;
	unsigned bytes_used = 0, bytes_free = 0;
	int i;

	printf("=== MMF DESCRIPTOR (MMFD) =====================\n"
	       "| MMF size: %ld bytes\n"
           "| No. of variables held in MMF: %ld\n"
           "| MMF Heap: bottom=%p\n"
           "|           top=%p\n"
           "|           watermark=%p\n",
           mmf->m_mmf_size,
           mmf->m_var_count,
           mmf->m_heap_bot,
           mmf->m_heap_top,
           mmf->m_kbrk);
    printf("+== HEAP STRUCTURE ============================\n");
    for(m = (MMF_MAP*)mmf->m_heap_bot; m != NULL; m = m->next)
	{
		printf("| blk %5p: %6lu bytes %s\n", m, m->size, m->used ? "used" : "free");
		if(m->used) {
			blks_used++;
			bytes_used += m->size;
		} else {
			blks_free++;
			bytes_free += m->size;
		}
	}
	printf("+----------------------------------------------\n");
	printf("| blks:  %6u used, %6u free, %6u total\n", blks_used,
		blks_free, blks_used + blks_free);
	printf("| bytes: %6u used, %6u free, %6u total\n", bytes_used,
		bytes_free, bytes_used + bytes_free);
	printf("+== VARIABLE DEFINITIONS ======================\n"
	       "| %-20s %-12s %-6s %s\n",
	       "Var_id", "Address", "Size", "Type");

    for (i=0;i<mmf->m_var_count;i++) {
        v = (MMF_VAR*)((char *)mmf + mmf->m_mmf_size - (1+i)*sizeof(MMF_VAR));
        printf("| %-20s %-12p %-6d %c\n",
               v->v_name, (char*)v->v_data, v->v_size,
               v->v_type ? 'C' : 'S');
    }
	printf("=== END OF REPORT =============================\n\n");
}


static void *__nbrk(MMF_DESCRIPTOR *mmf, unsigned *delta)
{
    char *new_brk, *old_brk;

    if (mmf->m_heap_bot == NULL) {		// heap doesn't exist yet
		mmf->m_heap_bot = mmf->m_kbrk = (char *) (mmf + 1);
	}

	new_brk = mmf->m_kbrk + (*delta);
	if(new_brk < mmf->m_heap_bot) { 	// too low: return NULL
	    // printf("*** __NBRK(): Too low\n");
		return NULL;
	}

	if(new_brk >= mmf->m_heap_top) {	// too high: return NULL
	    // printf("*** __NBRK(%p): Too high (%p)\n", new_brk, mmf->m_heap_top);
		return NULL;
	}

	old_brk = mmf->m_kbrk;				// success
	mmf->m_kbrk = new_brk;

	return(old_brk);
}


static void *__malloc(MMF_DESCRIPTOR *mmf, unsigned size)
{
	MMF_MAP *map, *m, *n;
	unsigned total_size;
	int delta;

	map = (MMF_MAP *) (mmf + 1);
	mmf->m_heap_top = (char *) mmf + mmf->m_mmf_size - mmf->m_var_count * sizeof(MMF_VAR);

	if (size == 0) {
        // printf("*** Zero-length malloc ignored in Malloc()\n");
		return NULL;
	}

    total_size = size + sizeof(MMF_MAP); // total size required

	// search heap for free block (FIRST FIT)
	m = (MMF_MAP *)mmf->m_heap_bot;
	if (m != NULL)
	{
		if(m->magic != MALLOC_MAGIC)
		{
			// printf("*** MMF is corrupt in Malloc()\n");
			return NULL;
		}

		for(; m->next != NULL; m = m->next)
		{
			if(m->used) continue;

			if((unsigned)size == m->size)		   // size == m->size is a perfect fit
				m->used = 1;
			else
			{	// otherwise, we need an extra sizeof(malloc_t) bytes for the header
				// of a second, free block
				if(total_size > m->size) continue;
				n = (MMF_MAP *)((char *)m + total_size); // create a new, smaller free block after this one
				n->size = m->size - total_size;
				n->next = m->next;
				n->magic = MALLOC_MAGIC;
				n->used = 0;	 // reduce the size of this block and mark it used
				m->size = size;
				m->next = n;
				m->used = 1;
			}
			return (void *)((char *)m + sizeof(MMF_MAP));
		}
	}

	delta = total_size;
    n = (MMF_MAP *)__nbrk(mmf, &delta);
	if (n == NULL) {
        // printf("*** __MALLOC: No NBRK\n");
		return NULL;
	}
	if(m != NULL) m->next = n;
	n->size = size;
	n->magic = MALLOC_MAGIC;
	n->used = 1;

	if((int)total_size == delta)
		n->next = NULL;
	else
	{
		/* it returned more than we wanted (it will never return less):
		   create a new, free block */
		m = (MMF_MAP *)((char *)n + total_size);
		m->size = delta - total_size - sizeof(MMF_MAP);
		m->next = NULL;
		m->magic = MALLOC_MAGIC;
		m->used = 0;
		n->next = m;
	}

	return (void *) ((char *)n + sizeof(MMF_MAP));
}


static void __free(MMF_DESCRIPTOR *mmf, void *szMEMORY)
{
	MMF_MAP *m, *n;

    // __dumpheap(mmf);

	// get address of header
	m = (MMF_MAP*)((char *) szMEMORY - sizeof(MMF_MAP));

	if(m->magic != MALLOC_MAGIC)
	{
		// printf("*** Attempt to Free() block at 0x%p with bad magic value\n", (char *)szMEMORY);
		return;
	}

	// find this block in the heap
	n = (MMF_MAP *)mmf->m_heap_bot;
	if(n->magic != MALLOC_MAGIC)
	{
		// printf("*** Shared Memory is corrupt in Free()\n");
		return;
	}
	for(; n != NULL; n = n->next)
	{
		if(n == m) break;
	}
	if(n == NULL)
	{
		// printf("*** Attempt to Free() block at 0x%p that is not in the shared memory\n", (char *)szMEMORY);
		return;
	}
	m->used = 0;

	// coalesce adjacent free blocks
	// Hard to spell, hard to do
	for(m = (MMF_MAP *)mmf->m_heap_bot; m != NULL; m = m->next)
	{
		while(!m->used && m->next != NULL && !m->next->used)
		{
			// resize this block
			m->size += sizeof(MMF_MAP) + m->next->size;
			// merge with next block
			m->next = m->next->next;
		}
	}
	
	// __dumpheap(mmf);
}


static void *__realloc(MMF_DESCRIPTOR *mmf, void *mem, unsigned size)
{
	MMF_MAP *m;
	void *new_blk;
	unsigned min;

	if ((long)size == 0)  // free block
	{
		if(mem != NULL) __free( mmf, mem );
		return NULL;
	} else {
		// allocate new block
		new_blk = __malloc( mmf, size );
		if (!new_blk) {
            // printf("*** No more available memory\n");
		}

		// if allocation OK, and if old block exists, copy old block to new
		if(new_blk != NULL && mem != NULL)
		{
			m = (MMF_MAP *)((char *)mem - sizeof(MMF_MAP));
			if(m->magic != MALLOC_MAGIC)
			{
				// printf("*** Attempt to Realloc() block at 0x%p with bad magic value\n", (char *)mem);
				return NULL;
			}
			// copy minimum of old and new block sizes
            min = (unsigned)size > m->size ? m->size : size;
			memcpy(new_blk, (char *)mem, min);
			m = (MMF_MAP *)((char *)new_blk - sizeof(MMF_MAP));
			m->size = size;
			__free( mmf, mem );
		}
	}
	return new_blk;
}


static MMF_VAR *__findvar(MMF_DESCRIPTOR *mmf, char *varname)
{
	MMF_VAR *var;
	long i;

	if (mmf->m_var_count > 0)
	{
		// point to the beginning of the var
		var = (MMF_VAR*)((char *)mmf + mmf->m_mmf_size - mmf->m_var_count * sizeof(MMF_VAR));

		for (i=mmf->m_var_count-1;i>=0;i--) {
			if (strcmp(var[i].v_name, varname) == 0) {
			    // printf("FOUND VAR: %s (WANTED %s)\n", var[i].v_name, varname);
				return &var[i];
			}
		}
	}

	return NULL;
}


static MMF_VAR *__createvar(MMF_DESCRIPTOR *mmf, char *varname)
{
	MMF_VAR *var;
	MMF_VAR *reuse = NULL;			// Reuse if already exists
	int i;

	if (mmf->m_var_count > 0)
	{
		// point to the beginning of the var
		var = (MMF_VAR*)((char *)mmf + mmf->m_mmf_size - mmf->m_var_count * sizeof(MMF_VAR));

		for (i=mmf->m_var_count-1;i>=0;i--) {
			if (strcmp(var[i].v_name, varname) == 0) {
				reuse = &var[i];
				break;
			}
		}
	}

	if (!reuse)
	{
		if (mmf->m_kbrk && mmf->m_kbrk >= mmf->m_heap_top) {
            // printf("*** No memory left to create variable!\n");
            return NULL;
		}

		++mmf->m_var_count;
		var = (MMF_VAR*)((char *)mmf + mmf->m_mmf_size - mmf->m_var_count * sizeof(MMF_VAR));

		memset(var, 0, sizeof(MMF_VAR));
		strcpy(var->v_name, varname);
		var->v_type = 0;
		var->v_size = 0;
		var->v_data = 0;

		if (mmf->m_heap_top != NULL) {
			mmf->m_heap_top = (char *) var;
		}
		return(var);
	}

	return reuse;
}


static int __setvar(MMF_DESCRIPTOR *mmf, char *varname, long type, char *value, long size)
{
    MMF_VAR *var;

	// find or create the variable
	var = __findvar(mmf, varname);
	if (!var) var = __createvar(mmf, varname);
	if (!var) return(0);

	// allocate memory to hold the variable
	if (var->v_data == 0) {
		var->v_data = (long) __malloc(mmf, size);
	} else {
        if (var->v_size != size) {
	       var->v_data = (long) __realloc(mmf, (void *)var->v_data, (unsigned)size);
	    }
    }
    
    var->v_size = size;
    var->v_type = type;

	if (!var->v_data) return(0);

    // transfer data into the allocated memory
    memcpy((char *)var->v_data, value, size);

	return(1);
}


static char *__getvar(MMF_DESCRIPTOR *mmf, char *varname, long *size)
{
	MMF_VAR *var;
	var = __findvar(mmf, varname);
	if (!var) return NULL;
	if (!var->v_data) return NULL;
	*size = var->v_size;
	return (char *)var->v_data;
}


static long __getvartype(MMF_DESCRIPTOR *mmf, char *varname)
{
	MMF_VAR *var;

    var = __findvar( mmf, varname );
    if (!var) return(-1);
    if (var->v_data == 0) return(-1);

    return(var->v_type);
}


static int __deletevar(MMF_DESCRIPTOR *mmf, char *varname)
{
	MMF_VAR *var, *m;

    var = __findvar( mmf, varname );
    if (!var) return(0);

    if (var->v_data != 0) {
        __free(mmf, (void *)var->v_data);
    }

    // point to the beginning of the var table
    m = (MMF_VAR*)((char *)mmf + mmf->m_mmf_size - mmf->m_var_count * sizeof(MMF_VAR));
    if (mmf->m_heap_top != NULL) mmf->m_heap_top = (char *)(m + 1);
    for (;m!=var;m++) {
        m[1] = *m;
    }
    mmf->m_var_count--;

    return(1);
}


MODULE = Win32::MMF 	PACKAGE = Win32::MMF

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
	char *ns = NULL;		// unique namespace / object-id
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


IV CreateSemaphore(IV initCount, IV maxCount, char *szNameSpace)
PREINIT:
	dMY_CXT;
	HANDLE hSemaphore;
CODE:
{
	if (initCount < 0 || maxCount <= 0)
	{
		XSRETURN_UNDEF;
	}

	hSemaphore = CreateSemaphore(
					NULL,			// no security attributes
					initCount,		// initial count
					maxCount,		// maximum count
					szNameSpace);	// unnamed semaphore

	if (hSemaphore == NULL) {
		XSRETURN_UNDEF;
	}

	RETVAL = (long) hSemaphore;
}
OUTPUT:
	RETVAL


IV WaitForSingleObject(IV hSemaphore, IV timeout)
PREINIT:
	dMY_CXT;
	HANDLE h;
	long t;
	long result;
CODE:
{
	if (!hSemaphore) {
		XSRETURN_UNDEF; // undef = error
	}
	h = (HANDLE) hSemaphore;
	if (timeout < 0) timeout = 0;
	t = timeout;

	result = (WaitForSingleObject(h, t) == WAIT_OBJECT_0) ? 1 : 0;

	RETVAL = (long)result;
}
OUTPUT:
	RETVAL


IV ReleaseSemaphore(IV hSemaphore, IV increment)
PREINIT:
	dMY_CXT;
CODE:
{
	if (!hSemaphore || (increment <= 0) )
	{
		XSRETURN_UNDEF; 	 // undef = error
	}

	if (!ReleaseSemaphore(
		(HANDLE)hSemaphore,  // handle to semaphore
		increment,			 // increase count by increment
		NULL) ) 			 // not interested in previous count
	{
		RETVAL = (IV)0;
	} else {
		RETVAL = (IV)1;
	}
}
OUTPUT:
	RETVAL



void InitMMF(IV szMMF, long size)
PREINIT:
	dMY_CXT;
	MMF_DESCRIPTOR *mmf;			// Initialize MMF
CODE:
{
	mmf = (MMF_DESCRIPTOR*) szMMF;	// point to the beginning of MMF descriptor

	mmf->m_mmf_size = size;
	mmf->m_var_count = 0;
	mmf->m_heap_bot = NULL;
	mmf->m_heap_top = NULL;
	mmf->m_kbrk = NULL;

	if (MY_CXT.debug) {
		printf("InitMMF: Address=%p Size=%ld\n", mmf, size);
		__dumpheap(mmf);
	}
}


IV Malloc(IV szMMF, IV size)
PREINIT:
	dMY_CXT;
CODE:
{
	RETVAL = (long) __malloc( (MMF_DESCRIPTOR*) szMMF, (unsigned) size );
}
OUTPUT:
	RETVAL


void Free(IV szMMF, IV szMEMORY)
PREINIT:
	dMY_CXT;
CODE:
{
	__free( (MMF_DESCRIPTOR*) szMMF, (void *) szMEMORY );
}



IV Realloc(IV szMMF, IV szMEMORY, IV size)
PREINIT:
	dMY_CXT;
CODE:
{
	RETVAL = (long) __realloc( (MMF_DESCRIPTOR *)szMMF, (void *)szMEMORY, (unsigned)size );
}
OUTPUT:
	RETVAL


void DumpHeap(IV szMMF)
CODE:
{
    __dumpheap( (MMF_DESCRIPTOR*) szMMF );
}


IV CreateVar(IV szMMF, char *varname)
PREINIT:
    MMF_VAR *var;
CODE:
{
    var = __createvar( (MMF_DESCRIPTOR *)szMMF, varname );
    if (!var) {
        XSRETURN_UNDEF;
    }
	RETVAL = (long) var;
}
OUTPUT:
	RETVAL


IV FindVar(IV szMMF, char *varname)
CODE:
{
	RETVAL = (long) __findvar( (MMF_DESCRIPTOR *)szMMF, varname );
}
OUTPUT:
	RETVAL


IV SetVar(IV szMMF, char *varname, IV type, char *value, long size)
PREINIT:
	dMY_CXT;
CODE:
{
	RETVAL = __setvar( (MMF_DESCRIPTOR*) szMMF, varname, (long) type, value, size );
}
OUTPUT:
	RETVAL


SV *GetVar(IV szMMF, char *varname)
PREINIT:
	dMY_CXT;
	char *data;
	long size;
CODE:
{
	data = __getvar((MMF_DESCRIPTOR*) szMMF, varname, &size);
    if (data == NULL) {
        XSRETURN_UNDEF;
    }

	RETVAL = newSVpvn( (LPVOID) data, size );
}
OUTPUT:
	RETVAL


IV GetVarType(IV szMMF, char *varname)
PREINIT:
	dMY_CXT;
	long type;
CODE:
{
    type = __getvartype((MMF_DESCRIPTOR*) szMMF, varname);
    if (type == -1) {
        XSRETURN_UNDEF;
    }

	RETVAL = type;
}
OUTPUT:
	RETVAL


IV DeleteVar(IV szMMF, char *varname)
PREINIT:
	dMY_CXT;
	int result;
CODE:
{
	RETVAL = ((result = __deletevar((MMF_DESCRIPTOR*) szMMF, varname)) == 1);
}
OUTPUT:
	RETVAL

