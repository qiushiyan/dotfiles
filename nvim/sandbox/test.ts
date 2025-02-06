import { add } from "./test2";
add(1, 2);
const obj = { test: "hello" };
// write a function that divies two numbers

function unusedFunctgon(req2: string) {
  var a = 1;

  return true ? true : false;
}
function unused(req: string) {
  return 1;
}
// test error symbols

type Status = {
  test: "pending" | "in-progress" | "done";
};

const s: Status = { test: "pending" };
varNotExists;
