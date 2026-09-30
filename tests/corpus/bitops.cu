#include <cstdio>
#include <cuda_runtime.h>

// Exercises the v1.1 bitwise operators (& | ^ << >> and unary ~) end-to-end.
// In the proved fragment (no __shared__, flat 1-D indexing), so it must
// transpile with exit 0. Kernel body mirrors tests/fixtures/bitops.minicuda.json,
// so the emitted kernel should match tests/expected/bitops.hip lines 3-13.
__global__ void bitmix(int *a, int *b, int *c, int n) {
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i < n) {
    int lo = a[i] & 255;
    int hi = a[i] >> 8;
    int packed = (hi << 8) | lo;
    int x = a[i] ^ b[i];
    int m = ~x;
    c[i] = packed & m;
  }
}

int main() {
  const int n = 1024;
  const size_t bytes = (size_t)n * sizeof(int);
  int *h_a = new int[n], *h_b = new int[n], *h_c = new int[n];
  for (int i = 0; i < n; ++i) {
    h_a[i] = i;
    h_b[i] = i * 3;
  }
  int *d_a, *d_b, *d_c;
  cudaMalloc(&d_a, bytes);
  cudaMalloc(&d_b, bytes);
  cudaMalloc(&d_c, bytes);
  cudaMemcpy(d_a, h_a, bytes, cudaMemcpyHostToDevice);
  cudaMemcpy(d_b, h_b, bytes, cudaMemcpyHostToDevice);
  bitmix<<<(n + 255) / 256, 256>>>(d_a, d_b, d_c, n);
  cudaDeviceSynchronize();
  cudaMemcpy(h_c, d_c, bytes, cudaMemcpyDeviceToHost);
  int bad = 0;
  for (int i = 0; i < n; ++i) {
    int lo = h_a[i] & 255;
    int hi = h_a[i] >> 8;
    int packed = (hi << 8) | lo;
    int x = h_a[i] ^ h_b[i];
    int m = ~x;
    if (h_c[i] != (packed & m)) ++bad;
  }
  printf(bad == 0 ? "PASS\n" : "FAIL %d\n", bad);
  cudaFree(d_a);
  cudaFree(d_b);
  cudaFree(d_c);
  delete[] h_a;
  delete[] h_b;
  delete[] h_c;
  return bad == 0 ? 0 : 1;
}
