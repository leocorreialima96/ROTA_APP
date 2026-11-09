import assert from "node:assert/strict";
import { test } from "node:test";

import { isValidCpf, maskCpf } from "../src/cpf";
import { cpfHash, decrypt, encrypt } from "../src/crypto";

test("valida CPF", () => {
  assert.equal(isValidCpf("529.982.247-25"), true);
  assert.equal(isValidCpf("52998224726"), false);
  assert.equal(isValidCpf("00000000000"), false);
  assert.equal(isValidCpf(""), false);
});

test("mascara CPF", () => {
  assert.equal(maskCpf("52998224725"), "***.982.247-**");
});

test("criptografa e descriptografa", () => {
  const key = Buffer.alloc(32, 1).toString("base64");
  const enc = encrypt("52998224725", key);
  assert.notEqual(enc.includes("52998224725"), true);
  assert.equal(decrypt(enc, key), "52998224725");
  assert.notEqual(encrypt("52998224725", key), enc, "IV aleatório");
});

test("hash do CPF é estável e depende da pimenta", () => {
  assert.equal(cpfHash("52998224725", "a"), cpfHash("52998224725", "a"));
  assert.notEqual(cpfHash("52998224725", "a"), cpfHash("52998224725", "b"));
});
