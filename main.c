#include "main.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "stack.h"

#define debug printf("%s:%d: ############### debug\n", __FILE__, __LINE__)

#define toupper(_char) (_char - (char)32)

const char* SymbolTypeName[] = {
    [UNDEFINED_TYPE] = "undefined",
    [AUTO_TYPE] = "auto",
    [VOID_TYPE] = "void",
    [CHAR_TYPE] = "char",
    [INT_TYPE] = "int",
    [LONG_TYPE] = "long",
    [FLOAT_TYPE] = "float",
    [DOUBLE_TYPE] = "double",
    [BOOL_TYPE] = "bool",
    [STR_TYPE] = "string",
    [FUNCTION_TYPE] = "function",
};

char* yyInputFileName;
bool compileError;

int indent = 0;
int scopeLevel = -1;
int funcLineNo = 0;
int variableAddress = 0;
int tableIndex = -1;

Stack s;

char* funcSig;
Type funcReturnType;
Type variableTypeRecord = UNDEFINED_TYPE;
char variableNameRecord[101] = "";

Table tables[100];

char* catDoller(const char* s1, const char* s2) {
    char* temp = (char*)calloc(strlen(s1) + strlen(s2) + 2, sizeof(char));
    strcpy(temp, s1);
    strcat(temp, " ");
    strcat(temp, s2);
    return temp;
}

char* typeToString(Type type) {
    return strdup(SymbolTypeName[type]);
}

void pushScope() {
    // Create a new symbol table and initialize it
    scopeLevel++;
    struct table* curTable = &tables[++tableIndex];
    curTable->scope = scopeLevel;
    curTable->size = 0;
    push(&s, tableIndex);
    printf("> Create symbol table (scope level %d)\n", scopeLevel);
}

void dumpScope() {
    // Print the symbol table
    struct table* curTable = &tables[pop(&s)];
    printf("\n> Dump symbol table (scope level: %d)\n", curTable->scope);
    printf("%-10s%-20s%-10s%-10s%-10s%-10s\n",
           "Index", "Name", "Type", "Addr", "Lineno", "Func_sig");
    for (int i = 0; i < curTable->size; i++) {
        struct symbol* curSymbol = &curTable->symbols[i];
        printf("%-10d%-20s%-10s%-10d%-10d%-10s\n",
               curSymbol->index, curSymbol->name, curSymbol->type, curSymbol->addr, curSymbol->lineno, curSymbol->func_sig);
    }
    scopeLevel--;
}

void setVarType(Type type) {
    variableTypeRecord = type;
}

Type getVarType() {
    return variableTypeRecord;
}

Type getVarTypeByStr(char* type) {
    for (int i = 0; i < sizeof(SymbolTypeName) / sizeof(SymbolTypeName[0]); i++) {
        if (strcmp(SymbolTypeName[i], type) == 0) {
            return i;
        }
    }
    return UNDEFINED_TYPE;
}

void initJNISignature(char* defaultSig) {
    funcSig = (char*)calloc(101, sizeof(char));
    if (funcSig != NULL) {
        strcpy(funcSig, defaultSig);
    } else {
        funcSig[0] = '(';
        funcSig[1] = '\0';
    }
}

void buildJNISignature(Type type, bool isArr) {
    // Build JNI signature
    if (isArr) {
        strcat(funcSig, "[");
    }
    switch (type) {
        case INT_TYPE:
            strcat(funcSig, "I");
            break;
        case FLOAT_TYPE:
            strcat(funcSig, "F");
            break;
        case BOOL_TYPE:
            strcat(funcSig, "B");
            break;
        case STR_TYPE:
            strcat(funcSig, "Ljava/lang/String;");
            break;
        case VOID_TYPE:
            strcat(funcSig, "V");
            break;
        default:
            strcat(funcSig, ")");
            buildJNISignature(funcReturnType, false);
            break;
    }
}

char* getJNISignature() {
    return funcSig;
}

char* getReturnTypeByJNISignature(char* signature) {
    const char* d = ")";
    char* p = strtok(signature, d);
    p = strtok(NULL, d);
    char* returnType = (char*)calloc(101, sizeof(char));
    if (strcmp(p, "I") == 0) {
        strcpy(returnType, "int");
    } else if (strcmp(p, "F") == 0) {
        strcpy(returnType, "float");
    } else if (strcmp(p, "B") == 0) {
        strcpy(returnType, "bool");
    } else if (strcmp(p, "Ljava/lang/String;") == 0) {
        strcpy(returnType, "string");
    } else if (strcmp(p, "V") == 0) {
        strcpy(returnType, "void");
    }
    return returnType;
}

Symbol* createSymbol(Type type, char* name, int flag, bool is_function, bool is_param, bool is_array) {
    // Create a new symbol
    struct table* curTable = &tables[peek(&s)];
    struct symbol* newSymbol = &curTable->symbols[curTable->size];
    newSymbol->name = strdup(name);
    strcpy(variableNameRecord, name);
    if (is_function) {
        newSymbol->type = strdup("function");
        funcReturnType = type;
        newSymbol->func_sig = funcSig;
        newSymbol->addr = -1;
    } else {
        type = (type == UNDEFINED_TYPE ? variableTypeRecord : type);
        newSymbol->type = strdup(SymbolTypeName[type]);
        newSymbol->func_sig = "-";
        newSymbol->addr = variableAddress++;
    }
    newSymbol->lineno = yylineno;
    newSymbol->index = curTable->size;
    curTable->size++;

    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, newSymbol->addr, scopeLevel);
    return newSymbol;
}

Symbol* findSymbol(char* name, bool is_function) {
    int h = height(&s);
    int* stack = all(&s);
    Symbol* curSymbol = NULL;
    for (int i = h; i >= 0; i--) {
        Table* curTable = &tables[stack[i]];
        for (int j = 0; j < curTable->size; j++) {
            curSymbol = &curTable->symbols[j];
            if (strcmp(curSymbol->name, name) == 0 && (!is_function ? strcmp(curSymbol->type, "function") != 0 : strcmp(curSymbol->type, "function") == 0)) {
                return curSymbol;
            }
        }
    }
    return NULL;
}

char* getSymbolType(char* name, bool is_function) {
    Symbol* curSymbol = findSymbol(name, is_function);
    if (strcmp(curSymbol->type, "function") == 0) {
        printf("IDENT (name=%s, address=%d)\n", curSymbol->name, curSymbol->addr);
        printf("call: %s%s\n", curSymbol->name, curSymbol->func_sig);
        return getReturnTypeByJNISignature(strdup(curSymbol->func_sig));
    } else {
        printf("IDENT (name=%s, address=%d)\n", curSymbol->name, curSymbol->addr);
    }
    return strdup(curSymbol->type);
}

void updateSymbolType(char* name, Type type) {
    Symbol* curSymbol = findSymbol(name == NULL ? variableNameRecord : name, false);
    curSymbol->type = strdup(SymbolTypeName[type]);
}

void debugPrintInst(char instc, Symbol* a, Symbol* b, Symbol* out) {
}

bool expression(char op, Symbol* dest, Symbol* val, Symbol* out) {
    return false;
}

bool expBinary(char op, Symbol* a, Symbol* b, Symbol* out) {
    return false;
}

bool expBoolean(char op, Symbol* a, Symbol* b, Symbol* out) {
    return false;
}

bool expAssign(char op, Symbol* dest, Symbol* val, Symbol* out) {
    return false;
}

bool valueAssign(Symbol* dest, Symbol* val, Symbol* out) {
    return false;
}

bool notBinaryExpression(Symbol* dest, Symbol* out) {
    return false;
}

bool negExpression(Symbol* dest, Symbol* out) {
    return false;
}
bool notExpression(Symbol* dest, Symbol* out) {
    return false;
}

bool incAssign(Symbol* a, Symbol* out) {
    return false;
}

bool decAssign(Symbol* a, Symbol* out) {
    return false;
}

bool cast(Type type, Symbol* dest, Symbol* out) {
    return false;
}

void pushFunInParm(Symbol* variable) {
}

int main(int argc, char* argv[]) {
    initStack(&s);
    char* outputFileName = NULL;
    if (argc == 3) {
        yyin = fopen(yyInputFileName = argv[1], "r");
        yyout = fopen(outputFileName = argv[2], "w");
    } else if (argc == 2) {
        yyin = fopen(yyInputFileName = argv[1], "r");
        yyout = stdout;
    } else {
        printf("require input file");
        exit(1);
    }
    if (!yyin) {
        printf("file `%s` doesn't exists or cannot be opened\n", yyInputFileName);
        exit(1);
    }
    if (!yyout) {
        printf("file `%s` doesn't exists or cannot be opened\n", outputFileName);
        exit(1);
    }

    code(".source Main.j\n");
    code(".class public Main\n");
    code(".super java/lang/Object\n");

    // Start parsing
    yyparse();
    printf("Total lines: %d\n", yylineno);
    fclose(yyin);

    yylex_destroy();
    return 0;
}