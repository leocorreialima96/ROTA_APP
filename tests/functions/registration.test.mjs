// Testa as funções de servidor rodando no simulador (auth, firestore e functions).
import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { initializeApp, deleteApp } from "firebase/app";
import { connectAuthEmulator, createUserWithEmailAndPassword, getAuth, signOut } from "firebase/auth";
import { connectFirestoreEmulator, doc, getDoc, getFirestore } from "firebase/firestore";
import { connectFunctionsEmulator, getFunctions, httpsCallable } from "firebase/functions";
import { initializeTestEnvironment } from "@firebase/rules-unit-testing";

const PROJECT = "demo-rota";
let app, auth, fns, db, admin;

before(async () => {
  app = initializeApp({ projectId: PROJECT, apiKey: "demo-key", appId: "demo-app" });
  auth = getAuth(app);
  connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  fns = getFunctions(app, "southamerica-east1");
  connectFunctionsEmulator(fns, "127.0.0.1", 5001);
  db = getFirestore(app);
  connectFirestoreEmulator(db, "127.0.0.1", 8080);
  admin = await initializeTestEnvironment({ projectId: PROJECT, firestore: { host: "127.0.0.1", port: 8080 } });
});

after(async () => {
  await admin.cleanup();
  await deleteApp(app);
});

const register = (data) => httpsCallable(fns, "completeRegistration")(data);
async function asAdmin(path) {
  let snap;
  await admin.withSecurityRulesDisabled(async (ctx) => { snap = await getDoc(doc(ctx.firestore(), path)); });
  return snap;
}

async function newUser(email) {
  await signOut(auth);
  const { user } = await createUserWithEmailAndPassword(auth, email, "senha-de-teste-123");
  return user;
}

test("cadastro válido cria o perfil com CPF mascarado e criptografado", async () => {
  const user = await newUser(`ana${Date.now()}@example.com`);
  const res = await register({ name: "Ana Paula Souza", cpf: "529.982.247-25", consent: true, plate: "abc1d23" });
  assert.equal(res.data.cpfMasked, "***.982.247-**");

  const profile = await getDoc(doc(db, `users/${user.uid}`));
  assert.equal(profile.get("name"), "Ana Paula Souza");
  assert.equal(profile.get("cpfMasked"), "***.982.247-**");
  assert.equal(profile.get("plate"), "ABC1D23");
  assert.equal(JSON.stringify(profile.data()).includes("52998224725"), false, "CPF aberto não pode estar no perfil");

  const priv = await asAdmin(`users/${user.uid}/private/identity`);
  assert.match(priv.get("cpfEncrypted"), /^v1:/);
  assert.equal(priv.get("cpfEncrypted").includes("52998224725"), false);
});

test("o mesmo CPF não abre uma segunda conta", async () => {
  await newUser(`outra${Date.now()}@example.com`);
  await assert.rejects(register({ name: "Outra Pessoa", cpf: "52998224725", consent: true }), (e) => {
    assert.equal(e.code, "functions/already-exists");
    return true;
  });
});

test("CPF inválido, nome incompleto e falta de consentimento são recusados", async () => {
  await newUser(`teste${Date.now()}@example.com`);
  await assert.rejects(register({ name: "Fulano de Tal", cpf: "111.111.111-11", consent: true }), /CPF inválido/);
  await assert.rejects(register({ name: "Fulano", cpf: "111.444.777-35", consent: true }), /nome completo/);
  await assert.rejects(register({ name: "Fulano de Tal", cpf: "111.444.777-35" }), /política de privacidade/);
});

test("sem login não cadastra", async () => {
  await signOut(auth);
  await assert.rejects(register({ name: "Fulano de Tal", cpf: "111.444.777-35", consent: true }), (e) => e.code === "functions/unauthenticated");
});

test("exclusão da conta apaga o perfil e libera o CPF", async () => {
  const user = await newUser(`sai${Date.now()}@example.com`);
  await register({ name: "Bruno Lima Costa", cpf: "111.444.777-35", consent: true });
  await httpsCallable(fns, "deleteMyAccount")({ confirm: "EXCLUIR" });
  const gone = await asAdmin(`users/${user.uid}`);
  assert.equal(gone.exists(), false);

  await newUser(`volta${Date.now()}@example.com`);
  const again = await register({ name: "Bruno Lima Costa", cpf: "111.444.777-35", consent: true });
  assert.equal(again.data.ok, true, "o CPF pode ser usado de novo depois da exclusão");
});
