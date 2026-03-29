import 'package:postgres/postgres.dart';
void main() {
  PoolSettings(maxConnectionCount: 3, sslMode: SslMode.disable);
}
