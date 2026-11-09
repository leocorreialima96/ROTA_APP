// Validação de CPF (mesma regra do app, em app/lib/core/cpf.dart).

export function cpfDigits(input: string): string {
  return String(input ?? "").replace(/\D/g, "");
}

export function isValidCpf(input: string): boolean {
  const d = cpfDigits(input);
  if (d.length !== 11 || /^(\d)\1{10}$/.test(d)) return false;
  const n = d.split("").map(Number);
  const check = (len: number): number => {
    let sum = 0;
    for (let i = 0; i < len; i++) sum += n[i] * (len + 1 - i);
    const r = (sum * 10) % 11;
    return r === 10 ? 0 : r;
  };
  return check(9) === n[9] && check(10) === n[10];
}

/** 52998224725 -> ***.982.247-** */
export function maskCpf(input: string): string {
  const d = cpfDigits(input);
  if (d.length !== 11) return "***.***.***-**";
  return `***.${d.slice(3, 6)}.${d.slice(6, 9)}-**`;
}
