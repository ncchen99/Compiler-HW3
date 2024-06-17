// stack.h

#ifndef STACK_H
#define STACK_H

#define MAX 100  // 堆疊的最大大小

// 定義堆疊結構
typedef struct stack {
    int data[MAX];
    int top;
} Stack;

// 函數聲明
void initStack(Stack *s);
int isEmpty(Stack *s);
int isFull(Stack *s);
void push(Stack *s, int value);
int pop(Stack *s);
int peek(Stack *s);
int *all(Stack *s);
int height(Stack *s);

#endif  // STACK_H
