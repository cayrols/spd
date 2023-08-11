#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <mpi.h>

/*
 * In this example, one of the ranks tries to access memory in a buffer
 * that is not allocated.
 */

#define PARAM_ERROR 1

#define N_EXAMPLE 3
enum {
  example_buffer_overflow=1,
  example_freed_memory,
  example_double_free,
};

//-----------------------------------------------------------------------------
void buffer_overflow(MPI_Comm comm) {
  int rank          = 0;
  int size          = 1;
  int failing_rank  = 0;
  int seed          = 0;
  double *buf = NULL;
  const int nval = 10000;
  size_t bufsize = nval * sizeof(double);

  MPI_Comm_rank( comm, &rank );
  MPI_Comm_size( comm, &size );

  // Generate random failing_rank
  srand(seed);
  failing_rank = (int)( rand() % size );

  // Description of the example
  if (! rank) {
    printf( "Example %s:\n"
        "\tAll ranks except one rank allocates memory and fill in\n",
        __FUNCTION__ );
    printf( "Failing_rank: %d\n", failing_rank );
  }

  // Reset the bufsize so that the failing rank does not allocate memory
  if ( rank == failing_rank )
    bufsize = 0;

  buf = (double*) malloc( bufsize );

  buf[0] = 0;
  // Code that generates segfault
  for ( int i = 1; i < nval; ++i )
    buf[i] = buf[i-1]/2 + i * 4;

  free( buf );
}

//-----------------------------------------------------------------------------
void freed_buffer(MPI_Comm comm) {
  int rank          = 0;
  int size          = 1;
  int failing_rank  = 0;
  int seed          = 0;
  double *buf = NULL;
  const int nval = 10000;
  size_t bufsize = nval * sizeof(double);

  MPI_Comm_rank( comm, &rank );
  MPI_Comm_size( comm, &size );

  // Generate random failing_rank
  srand(seed);
  failing_rank = (int)( rand() % size );

  // Description of the example
  if (! rank) {
    printf( "Example %s:\n"
        "\tA rank frees its memory before accessing it\n",
        __FUNCTION__ );
    printf( "Failing_rank: %d\n", failing_rank );
  }

  buf = (double*) malloc( bufsize );

  // Free the memory before accessing the data
  if ( rank == failing_rank )
    free( buf );

  buf[0] = 0;
  // Code that generates segfault
  for ( int i = 1; i < nval; ++i )
    buf[i] = buf[i-1]/2 + i * 4;

  free( buf );
}

//-----------------------------------------------------------------------------
void double_free(MPI_Comm comm) {
  int rank          = 0;
  int size          = 1;
  int failing_rank  = 0;
  int seed          = 0;
  double *buf = NULL;
  const int nval = 10000;
  size_t bufsize = nval * sizeof(double);

  MPI_Comm_rank( comm, &rank );
  MPI_Comm_size( comm, &size );

  // Generate random failing_rank
  srand(seed);
  failing_rank = (int)( rand() % size );

  // Description of the example
  if (! rank) {
    printf( "Example %s:\n"
        "\tA rank frees its memory twice\n",
        __FUNCTION__ );
    printf( "Failing_rank: %d\n", failing_rank );
  }

  buf = (double*) malloc( bufsize );

  // Free the memory before accessing the data
  if ( rank == failing_rank )
    free( buf );

  free( buf );
}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
#define USAGE "%s: <example_id: %d>\n" \
  "\texample_buffer_overflow: %d\n" \
  "\texample_freed_memory: %d\n" \
  "\texample_double_free: %d\n"

int main( int argc, char *argv[])
{
  int rank            = 0;
  int size            = 1;
  int default_example = example_freed_memory;
  int example         = 0;
  MPI_Comm comm;

  if (argc > 1) {
    if (!strcmp( argv[1], "-h" )) {
      printf( USAGE, argv[0], default_example,
          example_buffer_overflow, example_freed_memory, example_double_free );
      return PARAM_ERROR;
    }
    int given_param = atoi(argv[1]);
    if (given_param > 0  && given_param <= N_EXAMPLE)
      example = given_param;
    else {
      fprintf( stderr, "Error, value %d incorrect.\n", given_param );
      return PARAM_ERROR;
    }
  }

  MPI_Init( &argc, &argv );
  MPI_Comm_dup( MPI_COMM_WORLD, &comm );

  MPI_Comm_rank( comm, &rank );
  MPI_Comm_size( comm, &size );

  printf( "MPI info %d/%d\n", rank, size );

  switch (example) {
    case example_buffer_overflow:
      buffer_overflow( comm );
      break;
    case example_freed_memory:
      freed_buffer( comm );
      break;
    case example_double_free:
      double_free( comm );
      break;
  }
  
  MPI_Comm_free( &comm );
  MPI_Finalize();
  return 0;
}
