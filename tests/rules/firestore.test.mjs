import { after, before, beforeEach, describe, test } from "node:test";
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import {
  collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where, writeBatch,
} from "firebase/firestore";

import { env, expense, profile, report } from "./helpers.mjs";

let t;
const alice = () => t.authenticatedContext("alice").firestore();
const bob = () => t.authenticatedContext("bob").firestore();
const anon = () => t.unauthenticatedContext().firestore();

async function seed(path, data) {
  await t.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), path), data));
}

before(async () => { t = await env(); });
after(async () => { await t.cleanup(); });
beforeEach(async () => { await t.clearFirestore(); });

describe("users", () => {
  test("cada um lê só o próprio perfil", async () => {
    await seed("users/alice", profile());
    await assertSucceeds(getDoc(doc(alice(), "users/alice")));
    await assertFails(getDoc(doc(bob(), "users/alice")));
    await assertFails(getDoc(doc(anon(), "users/alice")));
  });

  test("o app não cria perfil nem escreve CPF: isso é do servidor", async () => {
    await assertFails(setDoc(doc(alice(), "users/alice"), profile()));
    await seed("users/alice", profile());
    await assertFails(updateDoc(doc(alice(), "users/alice"), { cpfMasked: "***.111.111-**", updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(alice(), "users/alice"), { cpfHash: "x", updatedAt: serverTimestamp() }));
  });

  test("edita nome, placa e categorias, mas não vira empresa sozinho", async () => {
    await seed("users/alice", profile());
    await assertSucceeds(updateDoc(doc(alice(), "users/alice"), {
      name: "Alice S. Souza", plate: "ABC1D23", mode: "individual",
      settings: { categories: [{ id: "hotel", name: "Hotel" }], byProject: false },
      onboardingDone: true, updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(alice(), "users/alice"), { mode: "company", updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(bob(), "users/alice"), { name: "Bob invasor", updatedAt: serverTimestamp() }));
  });

  test("dados privados (CPF criptografado) e índice de CPF são inacessíveis", async () => {
    await seed("users/alice/private/identity", { cpfEncrypted: "v1:..." });
    await seed("cpfIndex/abc", { uid: "alice" });
    await assertFails(getDoc(doc(alice(), "users/alice/private/identity")));
    await assertFails(getDoc(doc(alice(), "cpfIndex/abc")));
    await assertFails(setDoc(doc(alice(), "cpfIndex/zzz"), { uid: "alice" }));
  });
});

describe("expenses", () => {
  test("cria despesa própria e não cria em nome de outro", async () => {
    await assertSucceeds(setDoc(doc(alice(), "expenses/e1"), expense("alice")));
    await assertFails(setDoc(doc(alice(), "expenses/e2"), expense("bob")));
    await assertFails(setDoc(doc(anon(), "expenses/e3"), expense("alice")));
  });

  test("cliente é obrigatório e campos estranhos são recusados", async () => {
    await assertFails(setDoc(doc(alice(), "expenses/e1"), expense("alice", { client: "" })));
    await assertFails(setDoc(doc(alice(), "expenses/e1"), expense("alice", { amount: -1 })));
    await assertFails(setDoc(doc(alice(), "expenses/e1"), expense("alice", { hacker: true })));
    await assertFails(setDoc(doc(alice(), "expenses/e1"), expense("alice", { companyId: "empresaX" })));
    await assertFails(setDoc(doc(alice(), "expenses/e1"), expense("alice", { reportId: "r1" })));
  });

  test("outra conta não lê, não lista, não altera e não apaga", async () => {
    await seed("expenses/e1", expense("alice"));
    await assertFails(getDoc(doc(bob(), "expenses/e1")));
    await assertFails(getDocs(collection(bob(), "expenses")));
    await assertFails(getDocs(query(collection(bob(), "expenses"), where("ownerId", "==", "alice"))));
    await assertSucceeds(getDocs(query(collection(alice(), "expenses"), where("ownerId", "==", "alice"))));
    await assertFails(updateDoc(doc(bob(), "expenses/e1"), { amount: 1, updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(bob(), "expenses/e1")));
  });

  test("dono edita e apaga enquanto aberta; não troca de dono", async () => {
    await assertSucceeds(setDoc(doc(alice(), "expenses/e1"), expense("alice")));
    await assertSucceeds(updateDoc(doc(alice(), "expenses/e1"), { amount: 75, splitPeople: 2, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(alice(), "expenses/e1"), { ownerId: "bob", updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(doc(alice(), "expenses/e1")));
  });

  test("fechar o período: relatório e despesas no mesmo lote", async () => {
    await assertSucceeds(setDoc(doc(alice(), "expenses/e1"), expense("alice")));
    const db = alice();
    const b = writeBatch(db);
    b.set(doc(db, "reports/r1"), report("alice", ["e1"]));
    b.update(doc(db, "expenses/e1"), { reportId: "r1", updatedAt: serverTimestamp() });
    await assertSucceeds(b.commit());

    // Fechada: não edita, não apaga, não reabre.
    await assertFails(updateDoc(doc(alice(), "expenses/e1"), { amount: 1, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(alice(), "expenses/e1"), { reportId: null, updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(alice(), "expenses/e1")));

    // Mas a foto que estava só no celular pode terminar de subir.
    await assertSucceeds(updateDoc(doc(alice(), "expenses/e1"), {
      receipt: { state: "uploaded", path: "users/alice/receipts/e1.jpg", contentType: "image/jpeg" },
      updatedAt: serverTimestamp(),
    }));
  });

  test("não dá para jogar a despesa num relatório que não a lista ou de outra pessoa", async () => {
    await seed("expenses/e1", { ...expense("alice"), createdAt: new Date(), updatedAt: new Date() });
    await seed("reports/rBob", { ...report("bob", ["e1"]), updatedAt: new Date() });
    await seed("reports/rOutro", { ...report("alice", ["e9"]), updatedAt: new Date() });
    await assertFails(updateDoc(doc(alice(), "expenses/e1"), { reportId: "rBob", updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(alice(), "expenses/e1"), { reportId: "rOutro", updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(alice(), "expenses/e1"), { reportId: "naoExiste", updatedAt: serverTimestamp() }));
  });
});

describe("reports", () => {
  test("só o dono lê; ninguém apaga; emitido não muda de valor", async () => {
    await seed("reports/r1", { ...report("alice", ["e1"]), updatedAt: new Date() });
    await assertSucceeds(getDoc(doc(alice(), "reports/r1")));
    await assertFails(getDoc(doc(bob(), "reports/r1")));
    await assertFails(deleteDoc(doc(alice(), "reports/r1")));
    await assertFails(updateDoc(doc(alice(), "reports/r1"), { total: 9999, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(alice(), "reports/r1"), { status: "paid", updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(alice(), "reports/r1"), {
      files: { pdf: "users/alice/reports/r1.pdf" }, updatedAt: serverTimestamp(),
    }));
  });

  test("na fase 1 não se cria relatório aprovado, de empresa ou de outro", async () => {
    await assertFails(setDoc(doc(alice(), "reports/r1"), report("alice", ["e1"], { status: "approved" })));
    await assertFails(setDoc(doc(alice(), "reports/r1"), report("alice", ["e1"], { companyId: "empresaX" })));
    await assertFails(setDoc(doc(alice(), "reports/r1"), report("bob", ["e1"])));
    await assertFails(setDoc(doc(alice(), "reports/r1"), report("alice", [])));
  });
});

describe("coleções do servidor e da empresa", () => {
  test("ninguém lê ou escreve pelo app", async () => {
    for (const path of ["companies/c1", "memberships/m1", "activationCodes/a1", "auditLog/l1"]) {
      await seed(path, { x: 1 });
      await assertFails(getDoc(doc(alice(), path)));
      await assertFails(setDoc(doc(alice(), path), { x: 2 }));
    }
  });
});
