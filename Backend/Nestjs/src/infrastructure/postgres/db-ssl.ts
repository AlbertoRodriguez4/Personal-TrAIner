/// Cómo se conecta a Postgres: con TLS o sin él.
///
/// Vive aparte porque lo necesitan los dos puntos de entrada a la base de
/// datos —`app.module.ts` (la app) y `data-source.ts` (las migraciones)— y
/// tenerlo escrito dos veces es justo el fallo que se quiere evitar: que la
/// app conecte y las migraciones no, o al revés.

/// Hosts donde damos por hecho que no hay TLS delante: el Postgres del
/// portátil y el del `docker-compose.yml`, donde `DB_HOST: db` es el nombre
/// del servicio dentro de la red interna.
const HOSTS_SIN_TLS = new Set([
  'localhost',
  '127.0.0.1',
  '::1',
  'db',
  'postgres',
]);

/// Configuración `ssl` para node-postgres.
///
/// La decisión se toma **por el host, no por una variable de entorno**, y esa
/// es la parte que importa: los dos modos fallan, pero de formas opuestas y
/// asimétricas. Pedir TLS a un Postgres que no lo tiene revienta con "The
/// server does not support SSL connections"; no pedírselo a Neon revienta con
/// "connection is insecure (try using 'sslmode=require')". La diferencia es
/// que el primero se descubre en el acto, al arrancar en local, y el segundo
/// solo aparece en producción, que es donde menos se quiere descubrir nada.
/// Un flag que hay que acordarse de poner se olvida siempre en el mismo sitio.
///
/// `rejectUnauthorized: false` porque los Postgres gestionados (Neon, RDS)
/// sirven cadenas que Node no valida con su almacén de CA por defecto. Cifra
/// igual; lo que no hace es verificar el certificado del servidor.
///
/// `DB_SSL` sigue mandando cuando está puesta, para el caso raro que la tabla
/// de arriba no cubra: un Postgres local con TLS propio, o un host gestionado
/// que se llame `postgres`.
export function sslPostgres(): { rejectUnauthorized: boolean } | false {
  const explicito = process.env.DB_SSL?.trim().toLowerCase();
  if (explicito === 'true') return { rejectUnauthorized: false };
  if (explicito === 'false') return false;

  const host = (process.env.DB_HOST ?? 'localhost').trim().toLowerCase();
  return HOSTS_SIN_TLS.has(host) ? false : { rejectUnauthorized: false };
}
