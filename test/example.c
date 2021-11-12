#include <stdlib.h>
#include <stdio.h>
#include <mpi.h>

int main( int argc, char *argv[])
{
  int rank          = 0;
  int size          = 0;
  int failing_rank  = 0;
  int seed          = 0;
  double *buf = NULL;
  const int nval = 10000;
  size_t bufsize = nval * sizeof(double);

  MPI_Init( &argc, &argv );
  MPI_Comm_rank( MPI_COMM_WORLD, &rank );
  MPI_Comm_size( MPI_COMM_WORLD, &size );

  printf( "MPI info %d/%d\n", rank, size );

  // Generate random failing_rank
  srand(seed);
//failing_rank = (int)((rand() / RAND_MAX) * size);
  failing_rank = (int)(rand() % size);
  
  printf( "Failing_rank: %d\n", failing_rank );

  // Reset the bufsize so that the 
  if ( rank == failing_rank )
    bufsize = 0;

  buf = (double*) malloc( bufsize );

  buf[0] = 0;
  // Code that generates segfault
  for ( int i = 1; i < nval; ++i )
    buf[i] = buf[i-1]/2 + i * 4;

  MPI_Finalize();
  return 0;
}
