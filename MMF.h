#ifndef __MMF_H
#define __MMF_H


/* structure used to hold current MMF information */

typedef struct MMF_DESCRIPTOR {
    long  m_mmf_size;   // size of the MMF in bytes
    long  m_var_count;  // number of variables held in the MMF
    char *m_heap_bot;   // bottom of the heap
    char *m_heap_top;   // top of the heap
    char *m_kbrk;
} MMF_DESCRIPTOR;


/* structure used to hold definition for one variable */

typedef struct MMF_VAR {
    char v_name[32];    // variable name has to be less than 32 bytes
    long v_type;        // type of the variable held
    long v_data;        // LONG if IV, otherwise offset to variable
    long v_size;        // size of the data
} MMF_VAR;


/* structure used my malloc */

typedef struct MMF_MAP
{
    unsigned        size;
    struct MMF_MAP *next;
    unsigned        magic;
    unsigned        used;
} MMF_MAP;


#define	MALLOC_MAGIC	0x6D92


#endif

