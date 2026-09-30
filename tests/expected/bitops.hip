#include <hip/hip_runtime.h>

__global__ void bitmix(int *a, int *b, int *c, int n) {
  int i = ((blockIdx.x * blockDim.x) + threadIdx.x);
  if ((i < n)) {
    int lo = (a[i] & 255);
    int hi = (a[i] >> 8);
    int packed = ((hi << 8) | lo);
    int x = (a[i] ^ b[i]);
    int m = (~x);
    c[i] = (packed & m);
  }
}

int main() {
}
