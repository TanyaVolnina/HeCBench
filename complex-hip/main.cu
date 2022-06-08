#include <stdio.h>
#include <stdlib.h>
#include <chrono>
#include <hip/hip_runtime.h>
#include "complex.h"
#include "kernels.h"

bool check (const char *cs, int n)
{
  bool ok = true;
  for (int i = 0; i < n; i++) {
    if (cs[i] != 5) {
      ok = false; 
      break;
    }
  }
  return ok;
}

int main(int argc, char* argv[]) {
  if (argc != 3) {
    printf("Usage: %s <size> <repeat>\n", argv[0]);
    return 1;
  }
  const int n = atoi(argv[1]);
  const int repeat = atoi(argv[2]);

  char* cs = (char*) malloc (n);

  char* d_cs;
  hipMalloc((void**)&d_cs, n);

  dim3 grids ((n + 255)/256); 
  dim3 blocks (256);

  // warmup 
  complex_float<<<grids, blocks>>>(d_cs, n);
  complex_double<<<grids, blocks>>>(d_cs, n);
  hipDeviceSynchronize();

  auto start = std::chrono::steady_clock::now();

  // complex numbers in single precision
  for (int i = 0; i < repeat; i++) {
    hipLaunchKernelGGL(complex_float, grids, blocks, 0, 0, d_cs, n);
  }

  hipDeviceSynchronize();
  auto end = std::chrono::steady_clock::now();
  auto time = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
  printf("Average kernel execution time (float) %f (s)\n", time * 1e-9f / repeat);

  hipMemcpy(cs, d_cs, n, hipMemcpyDeviceToHost);
  bool complex_float_check = check(cs, n);

  start = std::chrono::steady_clock::now();

  // complex numbers in double precision
  for (int i = 0; i < repeat; i++) {
    hipLaunchKernelGGL(complex_double, grids, blocks, 0, 0, d_cs, n);
  }

  hipDeviceSynchronize();
  end = std::chrono::steady_clock::now();
  time = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
  printf("Average kernel execution time (double) %f (s)\n", time * 1e-9f / repeat);

  hipMemcpy(cs, d_cs, n, hipMemcpyDeviceToHost);
  bool complex_double_check = check(cs, n);

  printf("%s\n", (complex_float_check && complex_double_check)
                 ? "PASS" : "FAIL");

  hipFree(d_cs);
  free(cs);

  return 0;
}