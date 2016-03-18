FLEX=flex
CC=gcc

all: lexer

lexer: lex.yy.c
	$(CC) -D_ADD_MAIN -o $@ $< -g3 -O0

lex.yy.c: hw.lex
	$(FLEX) $<

clean:
	rm -rf lexer lex.yy.c
