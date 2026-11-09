/// Validação e formatação de CPF.
///
/// A mesma regra roda no servidor (functions/src/cpf.ts); aqui ela serve
/// para dar retorno imediato na tela de cadastro.
class Cpf {
  Cpf._();

  /// Mantém apenas os dígitos.
  static String digits(String input) => input.replaceAll(RegExp(r'\D'), '');

  static bool isValid(String input) {
    final d = digits(input);
    if (d.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
    final n = d.split('').map(int.parse).toList();
    int check(int len) {
      var sum = 0;
      for (var i = 0; i < len; i++) {
        sum += n[i] * (len + 1 - i);
      }
      final r = (sum * 10) % 11;
      return r == 10 ? 0 : r;
    }

    return check(9) == n[9] && check(10) == n[10];
  }

  /// 12345678909 -> 123.456.789-09 (formata parcialmente enquanto digita).
  static String format(String input) {
    final d = digits(input);
    final b = StringBuffer();
    for (var i = 0; i < d.length && i < 11; i++) {
      if (i == 3 || i == 6) b.write('.');
      if (i == 9) b.write('-');
      b.write(d[i]);
    }
    return b.toString();
  }

  /// 12345678909 -> ***.456.789-** (padrão de mascaramento da LGPD).
  static String mask(String input) {
    final d = digits(input);
    if (d.length != 11) return '***.***.***-**';
    return '***.${d.substring(3, 6)}.${d.substring(6, 9)}-**';
  }
}
