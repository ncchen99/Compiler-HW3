/* Definition section */
%{
    #include "compiler_common.h"
    #include "compiler_util.h"
    #include "main.h"

    int yydebug = 1;
    int array_element_count = 0;
    int is_main = 0, cmp_con = 0, label_counter = 0, for_label_counter = 0, for_label_array[5] = {1,2,3,4,5};
    char* func_name_backup = NULL;


    const InstructionMapping type2store[] = {
        {"string", "astore %d\n"},
        {"bool", "istore %d\n"},
        {"int", "istore %d\n"},
        {"float", "fstore %d\n"}
    };
    const InstructionMapping type2load[] = {
        {"string", "aload %d\n"},
        {"bool", "iload %d\n"},
        {"int", "iload %d\n"},
        {"float", "fload %d\n"}
    };
%}

/* Variable or self-defined structure */
%union {
    Type var_type;

    bool b_val;
    int i_val;
    float f_val;
    char *s_val;
    Object object_val;
    // Object object_val;
}

/* Token without return */
%token COUT 
%token SHR SHL BAN BOR BNT BXO ADD SUB MUL DIV REM NOT GTR LES GEQ LEQ EQL NEQ LAN LOR
%token VAL_ASSIGN ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN REM_ASSIGN BAN_ASSIGN BOR_ASSIGN BXO_ASSIGN SHR_ASSIGN SHL_ASSIGN INC_ASSIGN DEC_ASSIGN
%token IF ELSE FOR WHILE RETURN BREAK CONTINUE ENDL

/* Token with return, which need to sepcify type */
%token <var_type> VARIABLE_T
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STR_LIT IDENT 
%token <b_val> BOOL_LIT

/* Nonterminal with return, which need to sepcify type */
%type <object_val> Literal 
%type <object_val> Expression LogicalORExpr LogicalANDExpr ComparisonExpr AdditionExpr MultiplicationExpr UnaryExpr BitOperationExpr PrimaryExpr Operand Variable  ConversionExpr Declarator DeclaratorList DeclarationStmt
%type <s_val> cmp_op add_op mul_op unary_op assign_op bit_op
%type <s_val> PrintableList Printable
%type <i_val> IFTrue ForClause

%left ADD SUB
%left MUL DIV REM

/* Yacc will start at this nonterminal */
%start Program

%%
/* Grammar section */


Program
    : { pushScope();} GlobalStatementList { dumpScope(); }
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : FunctionDeclStmt
    | ';'       
;

FunctionDeclStmt
    : VARIABLE_T IDENT 
        {
            printf("func: %s\n", $<s_val>2);

            if(strcmp( $<s_val>2, "main")==0){
                initJNISignature("([Ljava/lang/String;)V");
                code(".method public static main([Ljava/lang/String;)V\n");
                code(".limit stack 100\n");
                code(".limit locals 100\n");
                is_main = 1;
            } else {
                initJNISignature(NULL);
                func_name_backup = strdup($<s_val>2);
                is_main = 0;
            }
            createSymbol($<var_type>1, $<s_val>2, VAR_FLAG_DEFAULT, true, false, false);
            pushScope();
        } '(' ParameterList ')'
        {
            if(!is_main){
                buildJNISignature(0, false);
                code(".method public static %s%s\n", func_name_backup, getJNISignature());
                code(".limit stack 70\n");
                code(".limit locals 70\n");
            } else {
                is_main = 0;
            }
        } FuncBlock 
;


ParameterList 
    : Parameter
    | ParameterList ',' Parameter
    |
;

Parameter
    : VARIABLE_T IDENT 
    { 
        createSymbol($<var_type>1, $<s_val>2, VAR_FLAG_DEFAULT, false, true, false);
        if(!is_main){
            buildJNISignature($<var_type>1, false);
        }
    }
    | VARIABLE_T IDENT '[' ']' 
    { 
        createSymbol($<var_type>1, $<s_val>2, VAR_FLAG_DEFAULT, false, true, true);
        if(!is_main){
            buildJNISignature($<var_type>1, true); 
        }
    }

FuncBlock
    : '{' StatementList '}' 
    {
        code("return\n");
        dumpScope();
        code(".end method\n");
    }
    | '{' StatementList RETURNStmt ';' '}' 
    {
        dumpScope();
        code(".end method\n");
    }



StatementList
    : Statement StatementList
    | Statement
;

Statement
    : Block
    | CoutStmt ';'
    | SimpleStmt ';'
    | IFStmt
    | FORStmt
    | WHILEstmt
    | BREAKStmt ';'
    | CONTINUEStmt ';'
;

SimpleStmt
    : AssignmentStmt
    | ExpressionStmt
    | IncDecStmt
    | DeclarationStmt
    |
;

AssignmentStmt
    : Expression assign_op Expression 
    {
        // if(strcmp($<s_val>1, $<s_val>3) != 0 ) {
        //     printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $<s_val>2, $<s_val>1, $<s_val>3);
        // } OK: int a = (float)(5.5)
        printf("%s\n", $<s_val>2);

        const InstructionMapping operations[] = {
            {"ADD_ASSIGN", "%cadd\n"},
            {"SUB_ASSIGN", "%csub\n"},
            {"MUL_ASSIGN", "%cmul\n"},
            {"DIV_ASSIGN", "%cdiv\n"},
            {"REM_ASSIGN", "%crem\n"},
            {"SHR_ASSIGN", "%cushr\n"},
            {"SHL_ASSIGN", "%cshl\n"},
            {"BAN_ASSIGN", "%cand\n"},
            {"BOR_ASSIGN", "%cor\n"},
            {"BXO_ASSIGN", "%cxor\n"}
        };

        if (strcmp($<object_val>1.type, $<object_val>3.type) != 0 && !(strcmp($<object_val>1.type, "bool") == 0 || strcmp($<object_val>3.type, "bool") == 0)) {
            code("%c2%c\n", tolower($<object_val>3.type[0]), tolower($<object_val>1.type[0]));
        }
        
        if(strcmp($<s_val>2, "EQL_ASSIGN") != 0){
            code(getInstruction(operations, 10, $<s_val>2), $<object_val>1.type[0]);
        }
        

        code(getInstruction(type2store, 4, $<object_val>1.type), $<object_val>1.addr);
    }
;


assign_op
    : VAL_ASSIGN {$$ = "EQL_ASSIGN";}
    | ADD_ASSIGN {$$ = "ADD_ASSIGN";}
    | SUB_ASSIGN {$$ = "SUB_ASSIGN";}
    | MUL_ASSIGN {$$ = "MUL_ASSIGN";}
    | DIV_ASSIGN {$$ = "DIV_ASSIGN";}
    | REM_ASSIGN {$$ = "REM_ASSIGN";}
    | SHR_ASSIGN {$$ = "SHR_ASSIGN";}
    | SHL_ASSIGN {$$ = "SHL_ASSIGN";}
    | BAN_ASSIGN {$$ = "BAN_ASSIGN";}
    | BOR_ASSIGN {$$ = "BOR_ASSIGN";}
    | BXO_ASSIGN {$$ = "BXO_ASSIGN";}
    // 可以直接 return "%cadd\n" 這種就好
;

ExpressionStmt
    : Expression
;

IncDecStmt
    : Expression INC_ASSIGN    
    {
        printf("INC_ASSIGN\n");
        code("ldc 1\n%cadd\nistore %d\n", $<object_val>1.type[0], $<object_val>1.addr);
    }
    | Expression DEC_ASSIGN    
    {
        printf("DEC_ASSIGN\n");
        code("ldc 1\n%csub\nistore %d\n",  $<object_val>1.type[0], $<object_val>1.addr);
    }
;


DeclarationStmt
    : VARIABLE_T { setVarType($<var_type>1); } DeclaratorList
;

DeclaratorList
	: Declarator
	| DeclaratorList ',' Declarator 
;

Declarator
    : IDENT 
    {
        Symbol* new = createSymbol(0, $<s_val>1, VAR_FLAG_DEFAULT, false, false, false);
        InstructionMapping type2const[] = {
            {"string", "ldc \"\"\n"},
            {"bool", "ldc 0\n"},
            {"int", "ldc 0\n"},
            {"float", "ldc 0.00000\n"}
        };
        code(getInstruction(type2const, 4, typeToString(getVarType())));
        code(getInstruction(type2store, 4, typeToString(getVarType())), new -> addr);
    }
	| IDENT VAL_ASSIGN Expression 
    {
        if(getVarType() == AUTO_TYPE){
            setVarType(getVarTypeByStr($<s_val>3));
        }
        // auto cast
        if (getVarType() != getVarTypeByStr($<object_val>3.type)) {
            code("%c2%c\n", tolower($<object_val>3.type[0]), tolower(typeToString(getVarType())[0]));
        }
        Symbol* new = createSymbol(0, $<s_val>1, VAR_FLAG_DEFAULT, false, false,false);
        code(getInstruction(type2store, 4, typeToString(getVarType())), new -> addr);
    }
	| IDENT '[' Expression ']' 
    {
		createSymbol(0, $<s_val>1, VAR_FLAG_DEFAULT, false, false, true);
	}
	| IDENT '[' Expression ']' '[' Expression ']' 
    {
		// printf("create array: %d\n", 0); 
		createSymbol(0, $<s_val>1, VAR_FLAG_DEFAULT, false, false, true);
	}
	| IDENT '[' Expression ']' VAL_ASSIGN { array_element_count = 0; } '{' ElementList '}' 
    {
		printf("create array: %d\n", array_element_count);
		createSymbol(0, $<s_val>1, VAR_FLAG_DEFAULT, false, false, true);
	}
;

ElementList
    : Element
    | ElementList ',' Element
    |
;

Element
    : Expression 
    {
        array_element_count += 1;
    }
;

Block  
    : '{' { pushScope(); } StatementList '}' { dumpScope(); }
; 

InitializedBlock
    : '{' StatementList '}' { dumpScope(); }


CoutStmt
	: COUT SHL PrintableList 
    { 
        printf("cout %s\n", $<s_val>3);
    }
;

PrintableList
    : Printable 
    {
        $$ = $<s_val>1;
    }
    | PrintableList SHL Printable
    {
        $$ = catDoller($<s_val>1, $<s_val>3);
    }
;

Printable
	: Expression
    {
        code("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
        code("swap\n");
        InstructionMapping type2print[] = {
            {"string", "invokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n"},
            {"bool", "invokevirtual java/io/PrintStream/print(Z)V\n"},
            {"int", "invokevirtual java/io/PrintStream/print(I)V\n"},
            {"float", "invokevirtual java/io/PrintStream/print(F)V\n"}
        };

        code(getInstruction(type2print, 4, $<object_val>1.type));
        $$ = $<object_val>1.type;
    }
;



IFStmt
    : IF '(' Expression ')' IFTrue ELSE IFFalse
    {
        code("L_if_end_%d:\n", $<i_val>5);
    }   
    | IF '(' Expression ')' IFTrue 
    {
        code("L_if_end_%d:\n", $<i_val>5);
    }
    ;

IFTrue
    : { code("ifeq L_else_begin_%d\n", ++label_counter); } Statement {
        code("goto L_if_end_%d\n", label_counter);
        code("L_else_begin_%d:\n", label_counter);
        $$ = label_counter;
    }
    ;

IFFalse
    : Statement

WHILEstmt
    : WHILE { 
        printf("WHILE\n"); code("L_while_start_%d:\n", ++label_counter);
    } '(' Condition ')' {
        code("ifeq L_while_end_%d\n", label_counter);
    } Statement {
        code("goto L_while_start_%d\n", label_counter);
        code("L_while_end_%d:\n", label_counter);
    }
;

Condition
    : Expression 
    {
        if(strcmp($<s_val>1, "bool") != 0){
            printf("error:%d: non-bool (type %s) used as for condition\n", yylineno + 1, $<s_val>1);
        }
    }
;

FORStmt
    : FOR { printf("FOR\n"); } '(' { pushScope(); } ForClause ')' InitializedBlock {
        code("goto L_for_start_%d\n", $<i_val>5);
        code("L_for_end_%d:\n", $<i_val>5);
    } 
;

ForClause
    : InitStmt ';' { code("L_for_start_%d:\n", ++label_counter); } Condition ';' {code("ifeq L_for_end_%d\n", label_counter);} PostStmt {
        $$ = label_counter; 
    }
    | DeclarationStmt ':' Expression 
    {
        $$ = label_counter;
        updateSymbolType(NULL, getVarTypeByStr($<s_val>3));
    }
    
;

InitStmt : SimpleStmt
PostStmt : SimpleStmt

BREAKStmt
    : BREAK
    {
        printf("BREAK\n");
    }
;   

RETURNStmt
    : RETURN Expression
    {
        printf("RETURN\n");
        char *sig = getJNISignature();
        if(sig[strlen(sig)-1] == 'V'){
            code("return\n");
        }else{
            code("%creturn\n", tolower(sig[strlen(sig)-1]) == 'z' ? 'i' : tolower(sig[strlen(sig)-1]));
        }
    }
    | RETURN
    {
        printf("RETURN\n");
        code("return\n");
    }
;

CONTINUEStmt
    : CONTINUE
    {
        printf("CONTINUE\n");
    }
;


Expression
    : LogicalORExpr {$$ = $1;}
;


LogicalORExpr
    : LogicalORExpr LOR LogicalANDExpr
    {
        if((strcmp($<object_val>1.type, "int") == 0)||(strcmp($<object_val>3.type, "int") == 0)){
            printf("error:%d: invalid operation: (operator LOR not defined on int32)\n", yylineno);
        }
        $$ = createObject("bool", "LOR", "0", -1, "");
        printf("LOR\n");
        code("ior\n");
    }
    | LogicalANDExpr LOR LogicalANDExpr
    {
        if((strcmp($<object_val>1.type, "int") == 0)||(strcmp($<object_val>3.type, "int") == 0)){
            printf("error:%d: invalid operation: (operator LOR not defined on int32)\n", yylineno);
        }
        $$ = createObject("bool", "LOR", "0", -1, "");
        printf("LOR\n");
        code("ior\n");
    }
    | LogicalANDExpr {$$ = $1;}
;

LogicalANDExpr
    : LogicalANDExpr LAN ComparisonExpr
    {
        if((strcmp($<object_val>1.type, "int") == 0)||(strcmp($<object_val>3.type, "int") == 0)){
            printf("error:%d: invalid operation: (operator LAND not defined on int32)\n", yylineno);
        }
        $$ = createObject("bool", "LAN", "0", -1, "");
        printf("LAN\n");
        code("iand\n");
    }
    | ComparisonExpr LAN ComparisonExpr
    {
        if((strcmp($<object_val>1.type, "int") == 0)||(strcmp($<object_val>3.type, "int") == 0)){
            printf("error:%d: invalid operation: (operator LAND not defined on int32)\n", yylineno);
        }
        $$ = createObject("bool", "LAN", "0", -1, "");
        printf("LAN\n");
        code("iand\n");
    }
    | ComparisonExpr {$$ = $1;}
;

ComparisonExpr
    : AdditionExpr cmp_op AdditionExpr
    {
        // if(strcmp($<object_val>1.type, $<object_val>1.type) != 0){
        //     printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $<s_val>2, $<object_val>1.type, $<object_val>1.type);
        // } else {
        if (strcmp($<object_val>1.type, "int") == 0 || strcmp($<object_val>1.type, "float") == 0 || strcmp($<object_val>1.type, "bool") == 0 ){
            code(($<object_val>1.type[0] == 'i' || $<object_val>1.type[0] == 'b') ? "isub\n" : "fcmpl\n");
            InstructionMapping type2cmp[] = {
                {"EQL", "ifeq L_cmp_%d\n"},
                {"NEQ", "ifne L_cmp_%d\n"},
                {"GTR", "ifgt L_cmp_%d\n"},
                {"LES", "iflt L_cmp_%d\n"},
                {"GEQ", "ifge L_cmp_%d\n"},
                {"LEQ", "ifle L_cmp_%d\n"}
            };
            code(getInstruction(type2cmp, 6, $<s_val>2), cmp_con);
            ++cmp_con;
            code("iconst_0\n");
            code("goto L_cmp_%d\n", cmp_con++);
            code("L_cmp_%d:\n", cmp_con-2);
            code("iconst_1\n");
            code("L_cmp_%d:\n", cmp_con-1);
        }
        // }
        $$ = createObject("bool", $<s_val>2, "0", -1, "");
        printf("%s\n", $<s_val>2);
    }
    | AdditionExpr {$$ = $1;}
;

AdditionExpr
    : MultiplicationExpr add_op MultiplicationExpr
    {
        if(strcmp($<object_val>1.type, $<object_val>3.type) != 0 ){
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $<s_val>2, $<s_val>1, $<s_val>3);
        } // TODO: auto cast
        $$ = $1;
        printf("%s\n", $<s_val>2);
        if (($<object_val>1.type[0] == 'i' && $<object_val>3.type[0] == 'b') || ($<object_val>1.type[0] == 'b' && $<object_val>3.type[0] == 'i')) {
            code("i%s\n", $<s_val>2);
            $$ = createObject("int", $<s_val>2, "0", -1, "");
        } else {
            code("%c%s\n", tolower($<object_val>1.type[0]), $<s_val>2);
        }
    }
    | AdditionExpr add_op MultiplicationExpr
    {
        $$ = $1;
        printf("%s\n", $<s_val>2);
        if (($<object_val>1.type[0] == 'i' && $<object_val>3.type[0] == 'b') || ($<object_val>1.type[0] == 'b' && $<object_val>3.type[0] == 'i')) {
            code("i%s\n", $<s_val>2);
            $$ = createObject("int", $<s_val>2, "0", -1, "");
        } else {
            code("%c%s\n", tolower($<object_val>1.type[0]), $<s_val>2);
        }
    }
    | MultiplicationExpr {$$ = $1;}
;

MultiplicationExpr
    : MultiplicationExpr mul_op BitOperationExpr
    {
        $$ = $1;
        printf("%s\n", $<s_val>2);
        code("%c%s\n", tolower($<s_val>1[0]), $<s_val>2);
    }
    | BitOperationExpr mul_op BitOperationExpr
    {
        if((strcmp($<s_val>2, "REM") == 0)&&(strcmp($<object_val>3.type, "float") == 0)){
            printf("error:%d: invalid operation: (operator REM not defined on float32)\n", yylineno);
        }
        $$ = $1;
        printf("%s\n", $<s_val>2);
        code("%c%s\n",  tolower($<s_val>1[0]) == 'b' ? 'i' : tolower($<s_val>1[0]), $<s_val>2);
    }
    | BitOperationExpr {$$ = $1;}
;

BitOperationExpr
    : BitOperationExpr bit_op BitOperationExpr { 
        if(strcmp($<object_val>1.type, "int") != 0 || strcmp($<object_val>3.type, "int") != 0){
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $<s_val>2, $<object_val>1.type, $<object_val>3.type);
        }
        $$ = $1;
        printf("%s\n", $<s_val>2);
        code("%c%s\n", tolower($<object_val>1.type[0]), $<s_val>2);
    }
    | UnaryExpr {$$ = $1;}
;



UnaryExpr
    : unary_op UnaryExpr 
    { 
        $$ = $2;
        printf("%s\n", $<s_val>1);
        if(strcmp($<s_val>1, "NOT")==0){
            code("iconst_1\n");
            if(strcmp($<s_val>2, "true")==0){
                code("iconst_1\n");
            }
            else if(strcmp($<s_val>2, "false")==0){
                code("iconst_0\n");
            }
            code("ixor\n");
            $$ = createObject("bool", "NOT", "0", -1, "");
        } else if(strcmp($<s_val>1, "BNT")==0){
            code("iconst_m1\n");
            code("ixor\n");
            $$ = createObject("int", "BNT", "0", -1, "");
        } else if(strcmp($<s_val>1, "NEG") == 0){
            code("%cneg\n", $<object_val>2.type[0]);
            $$ = createObject($<object_val>2.type, "NEG", "0", -1, "");
        }
    }
    | PrimaryExpr { $$ = $1; }
;


cmp_op 
    : EQL { $$ = "EQL"; }
    | NEQ { $$ = "NEQ"; }
    | LES { $$ = "LES"; }
    | LEQ { $$ = "LEQ"; }
    | GTR { $$ = "GTR"; }
    | GEQ { $$ = "GEQ"; }
;

add_op 
    : ADD { $$ = "add"; }
    | SUB { $$ = "sub"; }
;

mul_op 
    : MUL { $$ = "mul"; }
    | DIV { $$ = "div"; }
    | REM { $$ = "rem"; }
;

unary_op 
    : ADD { $$ = "POS"; }
    | SUB { $$ = "NEG"; }
    | NOT { $$ = "NOT"; }
    | BNT { $$ = "BNT"; }
;

bit_op
    : BAN { $$ = "and"; }
    | BOR { $$ = "or"; }
    /* | SHL { $$ = "SHL"; } */
    | SHR { $$ = "ushr"; }
    | BXO { $$ = "xor"; }
;


PrimaryExpr 
    : Operand { $$ = $<object_val>1; }
    | ConversionExpr { $$ = $<object_val>1; }
;

Operand 
    : Literal { $$ = $<object_val>1; }
    | Variable { $$ = $<object_val>1; }
    | '(' Expression ')' { $$ = $<object_val>2; }
;

Variable
    : IDENT 
    {         
        Symbol* cur = findSymbol($<s_val>1, false);
        $$ = createObject(cur -> type, cur -> name, "0", cur -> addr,"");
        
        code(getInstruction(type2load, 4, cur -> type), cur -> addr);
    }   
    | IDENT '(' ElementList ')' 
    { 
        Symbol* cur = findSymbol($<s_val>1, true);
        $$ =  createObject(getReturnTypeByJNISignature(cur -> func_sig), cur -> name, "0", cur -> addr,"");
        code("invokestatic Main/%s%s\n", cur -> name, cur -> func_sig);
    } 
    | IDENT '[' Expression ']' 
    {
        Symbol* cur = findSymbol($<s_val>1, false);
        $$ = createObject(cur -> type, cur -> name, "0", cur -> addr,"");
    }
    | IDENT '[' Expression ']' '[' Expression ']' 
    {
        Symbol* cur = findSymbol($<s_val>1, false);
        $$ = createObject(cur -> type, cur -> name, "0", cur -> addr,""); 
    }
;

ConversionExpr 
    : '(' VARIABLE_T ')' Operand 
    { 
        printf("Cast to %s\n", typeToString($<var_type>2)); 
        // $$ = typeToString($<var_type>2);
        if ($<var_type>2 != getVarTypeByStr($<object_val>4.type)) {
            code("%c2%c\n", tolower($<object_val>4.type[0]), tolower(typeToString($<var_type>2)[0]));
        }
        $$ = $<object_val>4;
        $$.type = typeToString($<var_type>2);
    }
;

Literal
    : INT_LIT
        {
            $$ = createObject("int", "LIT", convertAnyDataToString(&($<i_val>1), INT_TYPE), -1, "");
            printf("INT_LIT %d\n", $<i_val>1); 
            code("ldc %d\n", $<i_val>1);
        }
    | FLOAT_LIT
        {
            $$ = createObject("float", "LIT", convertAnyDataToString(&($<f_val>1), FLOAT_TYPE), -1, "");
            printf("FLOAT_LIT %f\n", $<f_val>1); 
            code("ldc %f\n", $<f_val>1);
        }
    | BOOL_LIT 
        {
            $$ = createObject("bool", "LIT", convertAnyDataToString(&($<b_val>1), BOOL_TYPE), -1, "");
            printf("BOOL_LIT %s\n", $<b_val>1 ? "TRUE" : "FALSE"); 
            code("%s\n", $<b_val>1 ? "iconst_1" : "iconst_0");
        }
    | STR_LIT 
        {
            $$ = createObject("string", "LIT", $<s_val>1, -1, "");
            printf("STR_LIT \"%s\"\n", $<s_val>1);
            code("ldc \"%s\"\n", $<s_val>1);
        }
    | ENDL 
        {   
            $$ = createObject("string", "LIT", "\\n", -1, "");
            printf("IDENT (name=endl, address=-1)\n");
            code("ldc \"\\n\"\n");
        }
;

%%
