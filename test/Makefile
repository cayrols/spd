SRC=example.c
OBJ=$(SRC:.c=)

all: ${OBJ}

%: %.c
	mpicc $< -o $@

clean:
	-${RM} ${OBJ}
