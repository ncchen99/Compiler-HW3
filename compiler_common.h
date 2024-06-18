#ifndef COMPILER_COMMON_H
#define COMPILER_COMMON_H

#include <ctype.h>
#include <stdbool.h>
#include <stdint.h>

typedef enum _type {
    UNDEFINED_TYPE,
    AUTO_TYPE,
    VOID_TYPE,
    CHAR_TYPE,
    INT_TYPE,
    LONG_TYPE,
    FLOAT_TYPE,
    DOUBLE_TYPE,
    BOOL_TYPE,
    STR_TYPE,
    FUNCTION_TYPE,
} Type;

typedef struct {
    char* name;
    char* type;
    char* func_sig;
    int addr;
} GeneralValue;

typedef struct {
    const char* returnVal;
    const char* inst;
} InstructionMapping;

//////////////// Symbol Table ////////////////
typedef struct symbol {
    char* name;
    char* type;
    char* func_sig;
    int addr;
    int lineno;
    int index;
} Symbol;

typedef struct _object {
    // Type type2;
    char* type;
    char* name;
    char* value;
    char* func_sig;
    int addr;
    void* array;
} Object;

typedef struct table {
    struct symbol symbols[101];
    int scope;
    int size;
} Table;

extern int yylineno;
extern int funcLineNo;

#endif /* COMPILER_COMMON_H */