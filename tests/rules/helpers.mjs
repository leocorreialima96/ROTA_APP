import { readFileSync } from "node:fs";
import { initializeTestEnvironment } from "@firebase/rules-unit-testing";
import { serverTimestamp, Timestamp } from "firebase/firestore";

export const PROJECT = "demo-rota";

export async function env() {
  return initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { rules: readFileSync("firebase/firestore.rules", "utf8") },
    storage: { rules: readFileSync("firebase/storage.rules", "utf8") },
  });
}

export function expense(ownerId, extra = {}) {
  return {
    ownerId,
    companyId: null,
    date: "2026-11-05",
    client: "Cliente A",
    activity: "Visita técnica",
    categoryId: "combustivel",
    noteAmount: 150,
    amount: 150,
    splitPeople: 1,
    notes: "",
    vehicleNotes: "",
    merchant: "Auto Posto",
    receipt: { state: "local", path: `users/${ownerId}/receipts/e1.jpg`, contentType: "image/jpeg" },
    source: "camera",
    reportId: null,
    projectId: null,
    localCreatedAt: Timestamp.now(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...extra,
  };
}

export function report(ownerId, expenseIds, extra = {}) {
  return {
    ownerId,
    companyId: null,
    mode: "period",
    periodStart: "2026-10-24",
    periodEnd: "2026-11-05",
    expenseIds,
    subtotal: 150,
    advances: 0,
    total: 150,
    status: "issued",
    fileBaseName: "Relatório de gastos técnicos 24-10-2026_05-11-2026_ALICE",
    createdAt: Timestamp.now(),
    updatedAt: serverTimestamp(),
    ...extra,
  };
}

export function profile(extra = {}) {
  return {
    name: "Alice Souza",
    cpfMasked: "***.982.247-**",
    cpfHash: "abc",
    email: "alice@example.com",
    phone: "",
    jobTitle: "",
    plate: "",
    mode: "undecided",
    settings: { categories: [], byProject: false },
    onboardingDone: false,
    ...extra,
  };
}
