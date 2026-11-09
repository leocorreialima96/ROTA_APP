import 'package:flutter_test/flutter_test.dart';
import 'package:rota/core/cpf.dart';

void main() {
  test('aceita CPFs válidos, com ou sem pontuação', () {
    expect(Cpf.isValid('529.982.247-25'), isTrue);
    expect(Cpf.isValid('52998224725'), isTrue);
    expect(Cpf.isValid('111.444.777-35'), isTrue);
  });

  test('recusa dígito errado, tamanho errado e sequências repetidas', () {
    expect(Cpf.isValid('529.982.247-26'), isFalse);
    expect(Cpf.isValid('5299822472'), isFalse);
    expect(Cpf.isValid('111.111.111-11'), isFalse);
    expect(Cpf.isValid(''), isFalse);
  });

  test('formata e mascara', () {
    expect(Cpf.format('52998224725'), '529.982.247-25');
    expect(Cpf.format('5299'), '529.9');
    expect(Cpf.mask('529.982.247-25'), '***.982.247-**');
  });
}
