%{
#include <unistd.h>
enum TOKEN_TYPE {
	IF,
	ELSE,
	FOR,
	COLON,
	LP,
	RP,
	LCP,
	RCP,
	IN,
	ID,
	STRING,
	INT,
	CMP_OP,
	ARITH_OP,
	COMMENT,
	INDENT,
	DEDENT,
	ERROR,
};

struct token {
	enum TOKEN_TYPE type;
	const char *type_name;
	union {
		int int_val;
		char *string_val;
	};
};

static void _process_token(int type, const char *type_name);
#define process_token(type)				\
	_process_token(type, #type)

static void process_newline();
static void process_leading_whitespace();
static void process_eof();
static unsigned int col = 1;

#define MAX_SCOPES (22)
static unsigned int indents[MAX_SCOPES] = { 0, 0, };
static unsigned int current_scope = 0;
static struct list_node {
	char c;
	struct list_node *next;
	unsigned int line;
} *comment_start = NULL, *comment_end;
static unsigned int comment_start_line;

static void comment_begin();
static void comment_append();
static void comment_print();
static void comment_eof();

%}

%option yylineno
%option noyywrap

digit 		([0-9])
whitespace	([\t\n ])
lp          	([(])
rp          	([)])
lcp          	([{])
rcp          	([}])
id 		([a-zA-Z][a-zA-Z0-9_]*)
string		(\"[^\"]*\")
cmp_op 		(<|>|==)
arith_op 	(\+|-|:=)
comment 	(\/\*.*?\*\/)
int             ([1-9][0-9]*)

%x COMMENT
comment_start   (\/\*)
comment_body    ([.\n])
comment_end     (\*\/)
%%

{comment_start}         BEGIN(COMMENT);comment_begin();
<COMMENT>\n 		comment_append();
<COMMENT>. 		comment_append();
<COMMENT>{comment_end}  comment_print(); BEGIN(INITIAL);
<COMMENT><<EOF>>	comment_eof(); yyterminate();

^[ ]*	process_leading_whitespace();
if 		process_token(IF);
else 		process_token(ELSE);
for 		process_token(FOR);
:		process_token(COLON);
{lp}		process_token(LP);
{rp}		process_token(RP);
{lcp}		process_token(LCP);
{rcp}		process_token(RCP);
in		process_token(IN);
{id}		process_token(ID);
{string}	process_token(STRING);
0		process_token(INT);
{int}		process_token(INT);

{cmp_op}	process_token(CMP_OP);
{arith_op}	process_token(ARITH_OP);
\n		process_newline();
{whitespace}	;
.		process_token(ERROR);
<<EOF>>         process_eof(); yyterminate();

%%
void _process_leading_whitespace(int indent);

unsigned int occurs(const char *string, int c)
{
	unsigned int count = 0;
	while (*string)
		count += *(string++) == c ? 1 : 0;
	return count;
}

void _process_token(int type, const char *type_name) {
	const char *val = "";

	switch (type) {
	case INDENT:
	case DEDENT:
		break;

	default:
		if (col == 1)
			_process_leading_whitespace(0);
		val = yytext;
	}
	col += yyleng;

	printf("%d %s %s\n", yylineno, type_name, val);
}

void process_leading_whitespace() {
	_process_leading_whitespace(strlen(yytext));
}

void _process_leading_whitespace(int indent) {
        col += indent;
	if (indents[current_scope] != indent) {
		if (indents[current_scope] < indent) {
			indents[++current_scope] = indent;
			process_token(INDENT);
		} else {
			int prev_scope = current_scope;
			while (prev_scope >= 0) {
				if (indents[prev_scope] == indent)
					break;
				prev_scope--;
			}
			if (prev_scope < 0) {
				printf("%d error in indentation\n", yylineno);
				exit(1);
			} else {
				while (current_scope > prev_scope) {
					process_token(DEDENT);
					current_scope--;
				}
			}
		}
	}
}

static void process_newline() {
	col = 1;
}

static void process_eof() {
	while (current_scope-- > 0)
		process_token(DEDENT);
}

static void comment_begin() {
	comment_start_line = yylineno;
	if (col == 1)
		_process_leading_whitespace(0);
}

static void comment_append() {
	struct list_node *new = malloc(sizeof (struct list_node));
	new->c = *yytext;
	new->next = NULL;
	new->line = yylineno;

	if (!comment_start) {
		comment_start = comment_end = new;
	} else {
		comment_end->next = new;
		comment_end = new;
	}
}

static void comment_print() {
	struct list_node *cur = comment_start;

	printf("%d COMMENT /*", yylineno);
	while (cur) {
		struct list_node *prev = cur;
		putchar(cur->c);
		cur = cur->next;
		free(prev);
	}
	puts("*/");

	comment_start = comment_end = NULL;
}

static void comment_eof() {
	struct list_node *cur = comment_start;

	printf("%d ERROR /\n", comment_start_line);
	printf("%d ERROR *\n", comment_start_line);

	while (cur) {
		struct list_node *prev = cur;

		switch (cur->c) {
		case '\n':
		case '\r':
		case '\t':
		case ' ':
			break;
		default:
			printf("%d ERROR %c\n", cur->line, cur->c);
		}

		cur = cur->next;
		free(prev);
	}
}

#ifdef _ADD_MAIN
int main() {
	yylex();
	return 0;
}
#endif
