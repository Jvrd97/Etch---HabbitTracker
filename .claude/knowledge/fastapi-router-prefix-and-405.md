# FastAPI: prefix роутеров, 405 от catch-all и openapi-fetch unwrap

## Проблема

Два независимых бага, которые вместе дают симптом "NOT VERIFIED / INACTIVE" на фронте:

1. `GET /api/users/me` → **405 Method Not Allowed** (бэкенд не слышит запрос)
2. `authUser.is_verified` и `authUser.is_active` всегда `undefined` (фронт не разворачивает ответ)

---

## Баг 1: пропущен prefix в `app.include_router()`

### Как работает FastAPI routing

```
APIRouter(prefix="/me")  →  маршруты: GET /me, PATCH /me
app.include_router(router)               →  реальный путь: GET /me
app.include_router(router, prefix="/api/users")  →  реальный путь: GET /api/users/me
```

Prefix складывается: `app.include_router(prefix)` + `APIRouter(prefix)` + `@router.get(path)`.

### Что случилось

В `main.py` роутер был подключён без префикса:

```python
# БЫЛО — неверно
app.include_router(user_api_router)   # routes at /me, /me/preferences/...
```

Фронт шлёт запросы на `/api/users/me`. Маршрут `/me` не совпадает.

### Почему 405, а не 404

В `user_router.py` есть catch-all OPTIONS:

```python
@router.options("/{path:path}", include_in_schema=False)
async def users_options(path: str = "") -> Response:
    return Response(status_code=204)
```

`/{path:path}` — это wildcard, который совпадает с ЛЮБЫМ путём, включая `/api/users/me`.
FastAPI видит: путь совпадает (через wildcard), но метод `GET` не зарегистрирован → **405 Method Not Allowed**.

Без catch-all был бы **404 Not Found**.

### Фикс

```python
# СТАЛО — верно
app.include_router(user_api_router, prefix="/api/users")
app.include_router(settings_router, prefix="/api/users/me/settings", tags=["users"])
```

### Правило

> **Всегда явно указывай `prefix` в `app.include_router()`.**
> Сверяй итоговый путь с тем, что зарегистрировано в openapi-types фронта (`/api/users/me` в `types/users.ts`).
> Проверяй через `/docs` swagger сразу после запуска сервиса.

---

## Баг 2: openapi-fetch возвращает `{ data, error, response }`, а не данные напрямую

### Как работает openapi-fetch

```ts
const result = await client.GET("/api/users/me")
// result = { data: ProfileResponse, error: null, response: Response }

result.data       // → ProfileResponse ✓
result.is_active  // → undefined ✗
```

`openapi-fetch` никогда не бросает исключение и не возвращает данные напрямую — он всегда возвращает обёртку.

### Что случилось

В `CabinetShell.tsx` результат сохранялся напрямую в state:

```ts
// БЫЛО — неверно
const [u, p] = await Promise.all([authApi.getCurrentUser(), userApi.getProfile()])
setAuthUser(u)   // u = { data: UserResponse, error: null, response: ... }
setProfile(p)    // p = { data: ProfileResponse, error: null, response: ... }

// в ProfilePanel.tsx:
authUser?.is_verified   // → undefined → "NOT VERIFIED"
authUser?.is_active     // → undefined → "INACTIVE"
```

TypeScript не ловил это потому что `authApi.getCurrentUser()` возвращает `Promise<FetchResponse<...>>`, а `useState<UserResponse | null>` — другой тип. Pyright/TS в этом месте не был достаточно строг из-за типа `any` в цепочке.

### Фикс

```ts
// СТАЛО — верно
const [uRes, pRes] = await Promise.all([authApi.getCurrentUser(), userApi.getProfile()])
if (uRes.error) throw new Error(String(uRes.response.status))
if (pRes.error) throw new Error(String(pRes.response.status))
setAuthUser(uRes.data ?? null)
setProfile(pRes.data ?? null)
```

### Правило

> **После каждого вызова openapi-fetch всегда делай `.data` unwrap и проверяй `.error`.**
> Никогда не сохраняй весь `FetchResponse` в state — только `.data`.
> Паттерн:
> ```ts
> const { data, error } = await client.GET(...)
> if (error) throw new Error(...)
> // работай с data
> ```

---

## Чек-лист при добавлении нового эндпоинта

1. **Бэкенд**: указан ли `prefix` в `app.include_router()`?
2. **Бэкенд**: проверь `/docs` — появился ли маршрут по нужному пути?
3. **Фронт**: генерируй `types/` из актуального OpenAPI schema сервиса.
4. **Фронт**: при вызове openapi-fetch всегда `const { data, error } = await client.GET(...)`.
5. **Фронт**: не сохраняй весь response-объект в state/переменную с типом domain-модели.

---

## Диагностика 405 в FastAPI

| Симптом | Причина |
|---|---|
| 405 на путь, которого "нет" | catch-all route (wildcard) совпадает по пути, но не по методу |
| 404 на путь, которого "нет" | ни один маршрут не совпал |
| 405 на существующий путь | маршрут есть, но зарегистрирован другой метод |

Для диагностики — открыть `/docs` на работающем сервисе и проверить список реальных маршрутов.
