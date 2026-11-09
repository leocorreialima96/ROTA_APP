import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { defineSecret } from "firebase-functions/params";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { cpfDigits, isValidCpf, maskCpf } from "./cpf";
import { cpfHash, encrypt } from "./crypto";

initializeApp();
setGlobalOptions({ region: "southamerica-east1", maxInstances: 10 });

// Em produção os segredos ficam no Secret Manager:
//   firebase functions:secrets:set CPF_ENCRYPTION_KEY   (32 bytes em base64)
//   firebase functions:secrets:set CPF_PEPPER
// No simulador (Emulator Suite) usamos valores de desenvolvimento.
const cpfKey = defineSecret("CPF_ENCRYPTION_KEY");
const cpfPepper = defineSecret("CPF_PEPPER");
const inEmulator = process.env.FUNCTIONS_EMULATOR === "true";
const DEV_KEY = Buffer.alloc(32, 7).toString("base64");
const DEV_PEPPER = "rota-dev-pepper";

function secrets(): { key: string; pepper: string } {
  if (inEmulator) {
    return { key: process.env.CPF_ENCRYPTION_KEY || DEV_KEY, pepper: process.env.CPF_PEPPER || DEV_PEPPER };
  }
  return { key: cpfKey.value(), pepper: cpfPepper.value() };
}

export const TERMS_VERSION = "2026-11";

function str(v: unknown, max: number): string {
  return typeof v === "string" ? v.trim().slice(0, max) : "";
}

/**
 * Cadastro (tela 2): valida o CPF, garante uma conta por CPF e cria o perfil.
 * O CPF nunca é gravado aberto: vai criptografado num documento que só o
 * servidor lê, e o app recebe apenas a versão mascarada.
 */
export const completeRegistration = onCall(
  { secrets: inEmulator ? [] : [cpfKey, cpfPepper] },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Entre na sua conta antes de se cadastrar.");

    const data = (req.data ?? {}) as Record<string, unknown>;
    const name = str(data.name, 120).replace(/\s+/g, " ");
    const cpf = cpfDigits(str(data.cpf, 20));
    if (name.length < 3 || !name.includes(" ")) {
      throw new HttpsError("invalid-argument", "Informe o nome completo, como deve sair no relatório.");
    }
    if (!isValidCpf(cpf)) throw new HttpsError("invalid-argument", "CPF inválido.");
    if (data.consent !== true) {
      throw new HttpsError("failed-precondition", "É preciso aceitar a política de privacidade e os termos de uso.");
    }

    const { key, pepper } = secrets();
    const hash = cpfHash(cpf, pepper);
    const db = getFirestore();
    const userRef = db.doc(`users/${uid}`);
    const indexRef = db.doc(`cpfIndex/${hash}`);
    const privateRef = db.doc(`users/${uid}/private/identity`);

    await db.runTransaction(async (tx) => {
      const [idx, user] = await Promise.all([tx.get(indexRef), tx.get(userRef)]);
      if (idx.exists && idx.get("uid") !== uid) {
        throw new HttpsError("already-exists", "Este CPF já tem uma conta na Rota. Entre com a conta original.");
      }
      if (user.exists && user.get("cpfHash") && user.get("cpfHash") !== hash) {
        throw new HttpsError("failed-precondition", "O CPF desta conta já foi cadastrado e não pode ser alterado.");
      }
      const now = FieldValue.serverTimestamp();
      tx.set(indexRef, { uid, createdAt: now });
      tx.set(privateRef, { cpfEncrypted: encrypt(cpf, key), updatedAt: now });
      tx.set(
        userRef,
        {
          name,
          cpfMasked: maskCpf(cpf),
          cpfHash: hash,
          email: req.auth?.token.email ?? str(data.email, 200),
          phone: str(data.phone, 30),
          jobTitle: str(data.jobTitle, 80),
          plate: str(data.plate, 10).toUpperCase(),
          mode: user.exists ? user.get("mode") ?? "undecided" : "undecided",
          settings: user.exists ? user.get("settings") ?? {} : { categories: [], byProject: false },
          onboardingDone: user.exists ? user.get("onboardingDone") === true : false,
          consent: { acceptedAt: now, termsVersion: TERMS_VERSION },
          createdAt: user.exists ? user.get("createdAt") ?? now : now,
          updatedAt: now,
        },
        { merge: true },
      );
      tx.create(db.collection("auditLog").doc(), {
        actor: uid,
        action: "user.registered",
        target: `users/${uid}`,
        at: now,
      });
    });

    return { ok: true, cpfMasked: maskCpf(cpf) };
  },
);

/**
 * LGPD: exclusão da conta pelo Perfil. Apaga despesas, relatórios, projetos,
 * fotos e o perfil. (Quando houver empresa, relatórios já enviados ficam com
 * ela pelo prazo legal de guarda fiscal.)
 */
export const deleteMyAccount = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Entre na sua conta.");
  if ((req.data as Record<string, unknown> | undefined)?.confirm !== "EXCLUIR") {
    throw new HttpsError("failed-precondition", "Confirmação ausente.");
  }
  const db = getFirestore();

  for (const col of ["expenses", "reports", "projects"]) {
    const snap = await db.collection(col).where("ownerId", "==", uid).get();
    let batch = db.batch();
    let n = 0;
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
      if (++n % 400 === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }
    await batch.commit();
  }

  const user = await db.doc(`users/${uid}`).get();
  const hash = user.get("cpfHash") as string | undefined;
  if (hash) await db.doc(`cpfIndex/${hash}`).delete();
  await db.recursiveDelete(db.doc(`users/${uid}`));

  try {
    await getStorage().bucket().deleteFiles({ prefix: `users/${uid}/` });
  } catch (e) {
    console.warn("Falha ao apagar arquivos do usuário", uid, e);
  }

  await db.collection("auditLog").add({
    actor: uid,
    action: "user.deleted",
    target: `users/${uid}`,
    at: FieldValue.serverTimestamp(),
  });
  await getAuth().deleteUser(uid);
  return { ok: true };
});
