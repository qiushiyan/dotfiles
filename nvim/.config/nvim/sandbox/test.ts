import { add } from "./test2";

add(1, 2);

const a = 1;

const obj = { test: "hello" };
console.log("obj:", obj);

const unusedFunction = (req2: string) => {
  var a = 1;
  return true ? true : false;
};

const unused = (req: string): number => {
  return 1;
};

type Status = {
  test: "pending" | "in-progress" | "done";
};

const s: Status = { test: "pending" };
const unused = (req: string): number => {
  return 1;
};

type Status = {
  test: "pending" | "in-progress" | "done";
};

const s: Status = { test: "pending" };
