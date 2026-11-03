# Seguridad de COLOSSEUM

## Modelo de amenazas

Hay que asumir que **cualquier cliente puede estar modificado**: puede enviar cualquier
valor por cualquier Remote, a cualquier ritmo, leer todo lo que esté en
`ReplicatedStorage` o en el `Workspace`, y mover libremente las piezas cuya física
controla (incluido su propio personaje).

## Reglas

### 1. El servidor decide
- El cliente envía intenciones (`AttackRequest`, `JoinQueue`), nunca resultados.
- Daño, golpes, victorias, recompensas, monedas y compras se calculan en el servidor.

### 2. Validar cada Remote
Cada handler comprueba, en este orden:
1. **Tipos**: `typeof` de cada argumento; números finitos (rechazar NaN e infinito);
   longitud máxima de textos y tablas.
2. **Límite de peticiones** por jugador y Remote.
3. **Estado**: ¿el jugador está vivo, en combate y es luchador activo?
4. **Reglas de juego**: cooldowns, distancia y línea de visión calculadas en el servidor.

Si falla, se ignora la petición y se registra. No se confía en ningún valor del cliente
para corregirla.

### 3. Lo secreto no se replica
- Lógica del servidor en `ServerScriptService`; datos y modelos privados en `ServerStorage`.
- `ReplicatedStorage` solo contiene lo que el cliente puede ver sin riesgo.

### 4. Movimiento y física
- El servidor comprueba distancias y velocidades razonables de los luchadores.
- Barcos, bestias y objetos de combate: el servidor mantiene la propiedad de red
  (`BasePart:SetNetworkOwner(nil)`) salvo decisión documentada.
- Las correcciones deben tolerar el lag para no castigar a jugadores legítimos.

### 5. Datos persistentes
- Bloqueo de sesión para evitar duplicación entre servidores.
- Guardar al salir el jugador y en `game:BindToClose`.
- Respetar los límites de `DataStoreService` (agrupar escrituras, reintentos con espera).
- Esquema versionado; nunca borrar campos sin migración.

### 6. Compras
- Conceder solo en `MarketplaceService.ProcessReceipt`.
- Idempotente: registrar `PurchaseId` y no conceder dos veces.
- Devolver `Enum.ProductPurchaseDecision.PurchaseGranted` solo tras guardar el resultado;
  si no, `NotProcessedYet`.
- Nunca conceder desde eventos del cliente ni desde `PromptProductPurchaseFinished`.
- Game Passes: verificar en el servidor con `MarketplaceService:UserOwnsGamePassAsync`.

### 7. Azar y dinero
- Prohibido: apuestas, cajas de botín de pago y cualquier azar ligado a Robux u objetos
  con valor monetario. No hay excepciones.

### 8. Texto y comunicación
- Todo texto de jugadores visible para otros pasa por el filtro de Roblox
  (`TextService` / `TextChatService`).

### 9. Secretos
- Ninguna clave (Open Cloud, webhooks) en el repositorio. `.env` está en `.gitignore`.
- Si en el futuro hacen falta, se usarán los mecanismos de secretos que Roblox documente
  (`POR VERIFICAR` cuando llegue el momento).

### 10. Herramientas administrativas
- Comandos de administrador solo en el servidor, con lista de `UserId` autorizados en
  `ServerStorage`, nunca comprobados en el cliente.

## Lista de revisión para cada PR

- [ ] ¿Algún Remote nuevo? ¿Tiene validador y límite de peticiones?
- [ ] ¿Algún dato sensible en `ReplicatedStorage`?
- [ ] ¿Algún valor del cliente se usa sin validar?
- [ ] ¿Se modifican datos guardados? ¿Hay migración?
- [ ] ¿Se toca monetización? ¿Sigue siendo idempotente y sin azar de pago?

## Informar de vulnerabilidades

Avisar en privado a los responsables del repositorio. No abrir issues públicos con detalles
de exploits.
