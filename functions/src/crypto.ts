import { createCipheriv, createDecipheriv, createHmac, randomBytes } from "node:crypto";

// Camada extra para CPF (e, na fase 2, dados bancários): o valor é
// criptografado no servidor com AES-256-GCM antes de ir para o banco, além da
// criptografia que o Google já aplica no armazenamento.

function keyFrom(secret: string): Buffer {
  const k = Buffer.from(secret, "base64");
  if (k.length !== 32) throw new Error("A chave de criptografia precisa ter 32 bytes em base64.");
  return k;
}

export function encrypt(plain: string, secret: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", keyFrom(secret), iv);
  const data = Buffer.concat([cipher.update(plain, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return ["v1", iv.toString("base64"), tag.toString("base64"), data.toString("base64")].join(":");
}

export function decrypt(payload: string, secret: string): string {
  const [v, iv, tag, data] = payload.split(":");
  if (v !== "v1") throw new Error("Formato desconhecido.");
  const d = createDecipheriv("aes-256-gcm", keyFrom(secret), Buffer.from(iv, "base64"));
  d.setAuthTag(Buffer.from(tag, "base64"));
  return Buffer.concat([d.update(Buffer.from(data, "base64")), d.final()]).toString("utf8");
}

/** Hash com "pimenta" secreta: permite achar CPF repetido sem guardar o número aberto. */
export function cpfHash(cpf: string, pepper: string): string {
  return createHmac("sha256", pepper).update(cpf).digest("hex");
}
