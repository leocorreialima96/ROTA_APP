import { after, before, beforeEach, describe, test } from "node:test";
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";
import { deleteObject, getBytes, ref, uploadBytes } from "firebase/storage";

import { env, expense } from "./helpers.mjs";

let t;
const jpg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
const meta = { contentType: "image/jpeg" };
const st = (uid) => (uid ? t.authenticatedContext(uid) : t.unauthenticatedContext()).storage();

before(async () => { t = await env(); });
after(async () => { await t.cleanup(); });
beforeEach(async () => { await t.clearFirestore(); await t.clearStorage(); });

describe("comprovantes", () => {
  test("dono sobe e lê a própria foto; outro e anônimo não", async () => {
    await assertSucceeds(uploadBytes(ref(st("alice"), "users/alice/receipts/e1.jpg"), jpg, meta));
    await assertSucceeds(getBytes(ref(st("alice"), "users/alice/receipts/e1.jpg")));
    await assertFails(getBytes(ref(st("bob"), "users/alice/receipts/e1.jpg")));
    await assertFails(getBytes(ref(st(null), "users/alice/receipts/e1.jpg")));
    await assertFails(uploadBytes(ref(st("bob"), "users/alice/receipts/e2.jpg"), jpg, meta));
  });

  test("só imagem, PDF ou XML", async () => {
    await assertFails(uploadBytes(ref(st("alice"), "users/alice/receipts/e1.exe"), jpg, { contentType: "application/x-msdownload" }));
    await assertSucceeds(uploadBytes(ref(st("alice"), "users/alice/receipts/e1.pdf"), jpg, { contentType: "application/pdf" }));
  });

  test("foto de despesa fechada não pode ser trocada nem apagada", async () => {
    await t.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "expenses/e7"), { ...expense("alice"), reportId: "r1", createdAt: new Date(), updatedAt: new Date() });
    });
    await assertSucceeds(uploadBytes(ref(st("alice"), "users/alice/receipts/e7.jpg"), jpg, meta));
    await assertFails(uploadBytes(ref(st("alice"), "users/alice/receipts/e7.jpg"), jpg, meta));
    // Despesa aberta: pode trocar a foto.
    await assertSucceeds(uploadBytes(ref(st("alice"), "users/alice/receipts/e8.jpg"), jpg, meta));
    await assertSucceeds(uploadBytes(ref(st("alice"), "users/alice/receipts/e8.jpg"), jpg, meta));
    await assertFails(deleteObject(ref(st("alice"), "users/alice/receipts/e7.jpg")));
  });

  test("pastas fora de users/{uid} estão fechadas", async () => {
    await assertFails(uploadBytes(ref(st("alice"), "publico/x.jpg"), jpg, meta));
  });
});
