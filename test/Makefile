SRC=example.c
OBJ=$(SRC:.c=)

all: ${OBJ}

%: %.c
	mpicc -g $< -o $@

clean:
	-${RM} ${OBJ}
