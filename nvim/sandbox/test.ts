function add(a: number, b: number): number {
  return a + b;
}

const a = 1;

namespace Test {
  export const b = 2;
}

function main() {
  console.log(add(a, Test.b));
}

// test error symbols
varNotExist





