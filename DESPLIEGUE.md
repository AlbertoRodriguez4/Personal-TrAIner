# Desplegar Personal TrAIner en Oracle Cloud Free Tier

Objetivo: usar la app desde el móvil, en cualquier red, sin tener el portátil
encendido.

Piezas: **NestJS** (API) + **Python** (IA) + **PostgreSQL**, los tres en una
máquina con Docker Compose, detrás de **Caddy** (HTTPS automático).

---

## 0. Antes de empezar

Necesitas un **dominio**. No es opcional: Android bloquea el tráfico HTTP en
claro, así que la app necesita `https://`, y para un certificado hace falta un
nombre. Uno `.com` cuesta ~10 €/año; un subdominio gratuito de DuckDNS también
sirve.

> **Ojo con la arquitectura.** El Free Tier bueno de Oracle (4 núcleos, 24 GB)
> es **ARM Ampere**, no x86. Los Dockerfiles se construyen en la propia máquina,
> así que esto se resuelve solo — pero si algún día compilas las imágenes en tu
> PC y las subes, tendrás que usar `docker buildx --platform linux/arm64`.

---

## 1. Crear la máquina

1. Entra en Oracle Cloud → *Compute* → *Instances* → **Create instance**.
2. **Image**: Ubuntu 22.04 (o 24.04).
3. **Shape**: *Ampere* → `VM.Standard.A1.Flex`. Pon **2 OCPU y 12 GB** (dentro
   del Free Tier). Con MediaPipe cargado, 1 GB se queda corto.
4. Guarda la clave SSH que te descarga: sin ella no vuelves a entrar.
5. Anota la **IP pública**.

> Si te dice *"Out of capacity"*, es lo normal en ARM. Prueba otro *availability
> domain*, u otra región, o repite al cabo de unas horas.

### Abrir los puertos (dos sitios, y el segundo se olvida siempre)

**a) En la consola de Oracle**: la *Virtual Cloud Network* → *Security List* →
añade reglas de entrada para **80** y **443** desde `0.0.0.0/0`.

**b) Dentro de la máquina** — Ubuntu en Oracle trae iptables cerrado de fábrica,
y aunque abras la consola, sigue sin entrar nada:

```bash
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

---

## 2. Apuntar el dominio

En tu proveedor de DNS, un registro **A** de `api.tudominio.com` → la IP pública.

Compruébalo antes de seguir; si no resuelve, Caddy no consigue el certificado:

```bash
dig +short api.tudominio.com
```

---

## 3. Preparar el servidor

```bash
ssh -i tu-clave.key ubuntu@LA_IP_PUBLICA

sudo apt update && sudo apt install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER
newgrp docker

git clone https://github.com/AlbertoRodriguez4/Personal-TrAIner.git
cd Personal-TrAIner
```

---

## 4. Configurar los secretos

```bash
cp .env.produccion.example .env
```

Genera los tres secretos y pégalos en el `.env`:

```bash
echo "DB_PASSWORD=$(openssl rand -base64 24)"
echo "JWT_SECRET=$(openssl rand -base64 48)"
echo "INTERNAL_API_KEY=$(openssl rand -base64 32)"
```

Rellena también `DOMINIO`, `GEMINI_API_KEY` y `GROQ_API_KEY`.

> **No reutilices la contraseña de la base de datos de desarrollo.** Es
> `password` y estuvo en el historial de git.

---

## 5. Levantarlo

```bash
docker compose up -d --build
```

La primera vez tarda: MediaPipe son varios cientos de megas y en ARM va sin
prisa. Después:

```bash
docker compose ps          # los cuatro en 'running'
docker compose logs -f api
```

### Crear las tablas

La base arranca vacía. Las migraciones se ejecutan una sola vez:

```bash
docker compose exec api npm run migration:run:prod
```

### Comprobar que responde

```bash
curl https://api.tudominio.com/users/login -X POST \
  -H "Content-Type: application/json" -d '{"email":"x","password":"y"}'
```

Un **401** es la respuesta correcta: significa que llegó, tiene HTTPS y la
autenticación está activa.

---

## 6. Compilar la app apuntando al servidor

En tu PC:

```bash
cd Frontend/personaltrainer
flutter build apk --release --dart-define=API_BASE_URL=https://api.tudominio.com
```

La APK sale en `build/app/outputs/flutter-apk/app-release.apk`. Pásala al móvil
e instálala (hay que permitir "orígenes desconocidos").

> **Sobre la firma:** ahora mismo se firma con la clave de depuración. Funciona
> para instalarla tú, pero si algún día generas una clave propia tendrás que
> **desinstalar** la app antes de actualizar, porque Android no deja reemplazar
> una APK con otra firma distinta. Si prevés actualizarla a menudo, crea el
> keystore desde el principio.

Como la cuenta se crea en el servidor nuevo, la base está vacía: regístrate otra
vez desde la app.

---

## 7. Mantenimiento

**Actualizar tras cambios:**
```bash
cd Personal-TrAIner && git pull && docker compose up -d --build
```

**Copia de seguridad de la base de datos** (los datos clínicos no están en
ningún otro sitio):
```bash
docker compose exec db pg_dump -U personaltrainer entrenador_ia_db > backup-$(date +%F).sql
```

**Restaurar:**
```bash
cat backup-2026-08-18.sql | docker compose exec -T db psql -U personaltrainer -d entrenador_ia_db
```

Merece la pena ponerlo en un `cron` semanal y descargarte el fichero.

---

## Si algo falla

| Síntoma | Causa habitual |
|---|---|
| Caddy no saca certificado | El DNS aún no propaga, o el puerto 80 sigue cerrado en iptables (paso 1b) |
| `api` reinicia sin parar | Falta `JWT_SECRET` en el `.env`, o tiene menos de 32 caracteres |
| La app da 401 en todo | La APK se compiló sin `--dart-define`, o el token caducó: vuelve a iniciar sesión |
| El análisis de físico falla | Poca RAM: sube la instancia a 12 GB o revisa `docker compose logs ia` |
| Todo va pero no guarda nada | Faltan las migraciones (paso 5) |
