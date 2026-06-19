# Этап 1: сборка self-contained исполняемого файла
FROM dart:stable AS build

WORKDIR /app

# Копируем манифесты зависимостей и загружаем их
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

# Копируем весь исходный код сервера
COPY . .

# Компилируем в нативный бинарник (нет JIT, минимальный образ)
RUN dart compile exe bin/server.dart -o /app/server_bin

# -------------------------------------------------------------------
# Этап 2: минимальный образ только с бинарником
FROM debian:bookworm-slim

WORKDIR /app

COPY --from=build /app/server_bin /app/server
RUN chmod +x /app/server

# Создаём папку для локального fallback (shelf_static требует наличия директории)
RUN mkdir -p /app/uploads/audio /app/uploads/artworks

EXPOSE 8080

CMD ["/app/server"]
