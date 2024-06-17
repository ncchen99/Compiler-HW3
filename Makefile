CFLAGS := -Wall -O0 -ggdb
YFLAG := -d -v
STACK_SRC := ./stack.c
MAIN_SRC := ./main.c
LEX_SRC := ./compiler.l
YAC_SRC := ./compiler.y
COMMON := ./compiler_common.h
BUILD := ./build
BUILD_OUT := out
COMPILER := compiler
EXEC := Main
INPUT_CPP := test.cpp



BUILD_OUT := ${BUILD}/out# 					Do not touch
COMPILER_OUT := ${BUILD_OUT}/${COMPILER}# 	Do not touch
LEX_OUT := ${BUILD}/lex.yy.c
YAC_OUT := ${BUILD}/y.tab.c
MAIN_OUT := ${BUILD}/main.o
STACK_OUT := ${BUILD}/stack.o

IN := ./input/subtask01-helloworld/testcase01.cpp
ASM_OUT := ${BUILD}/Main.j# 				Do not touch
PGM_OUT := ${BUILD_OUT}/${EXEC}.class# 		Do not touch

all: build compile_asm run

build: build_compiler # Do not edit

.PHONY: main.c

create_build_folder:
	mkdir -p ${BUILD}
	mkdir -p ${BUILD_OUT}

${LEX_OUT}: ${LEX_SRC}
	$(info ---------- Compile Lex ----------)
	lex -o ${LEX_OUT} ${LEX_SRC}

${YAC_OUT}: ${YAC_SRC}
	$(info ---------- Compile Yacc ----------)
	yacc ${YFLAG} -o ${YAC_OUT} ${YAC_SRC}

${STACK_OUT}: ${STACK_SRC}
	$(info ---------- Compile ${STACK_SRC} ----------)
	gcc -g -c ${STACK_SRC} -o ${STACK_OUT}

${MAIN_OUT}: ${MAIN_SRC}
	$(info ---------- Compile ${MAIN_SRC} ----------)
	gcc -g -c ${MAIN_SRC} -o ${MAIN_OUT}

build_compiler: create_build_folder ${LEX_OUT} ${YAC_OUT} ${STACK_OUT} ${MAIN_OUT}
	$(info ---------- Create compiler ----------)
	gcc ${CFLAGS} -o ${COMPILER_OUT} -iquote ./ -iquote ../ ${LEX_OUT} ${YAC_OUT} ${STACK_OUT} ${MAIN_OUT}

compile_cmm:
	$(info ---------- Compile c-- to Java ASM ----------)
	@rm -f ${ASM_OUT}
	${COMPILER_OUT} ${IN} ${ASM_OUT}

compile_asm: compile_cmm # Do not edit
	$(info ---------- Compile Java ASM to Java bytecode ----------)
	@test -f "${ASM_OUT}" || (echo "\"${ASM_OUT}\" does not exist."; exit 1)
	@rm -f ${PGM_OUT}
	@java -jar jasmin.jar -g ${ASM_OUT} -d ${BUILD_OUT}

run_nomsg: # Do not edit
	@cd ${BUILD_OUT} && java ${EXEC}

run:
	$(info ---------- Run program ----------)
	@test -f "${PGM_OUT}" || (echo "\"${PGM_OUT}\" does not exist."; exit 1)

	@cd ${BUILD_OUT} && java ${EXEC}

clean:
	rm -rf ${BUILD}
