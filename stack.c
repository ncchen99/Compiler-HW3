#include "stack.h"

#include <stdio.h>

// 初始化堆疊
void initStack(Stack *s) {
    s->top = -1;
}

// 判斷堆疊是否為空
int isEmpty(Stack *s) {
    return s->top == -1;
}

// 判斷堆疊是否已滿
int isFull(Stack *s) {
    return s->top == MAX - 1;
}

// 將元素推入堆疊
void push(Stack *s, int value) {
    if (isFull(s)) {
        printf("堆疊已滿，無法推入元素\n");
        return;
    }
    s->data[++s->top] = value;
}

// 從堆疊彈出元素
int pop(Stack *s) {
    if (isEmpty(s)) {
        printf("堆疊為空，無法彈出元素\n");
        return -1;  // 使用 -1 表示錯誤
    }
    return s->data[s->top--];
}

// 取得堆疊頂部元素
int peek(Stack *s) {
    if (isEmpty(s)) {
        printf("堆疊為空\n");
        return -1;  // 使用 -1 表示錯誤
    }
    return s->data[s->top];
}

int *all(Stack *s) {
    return s->data;
}

int height(Stack *s) {
    return s->top + 1;
}