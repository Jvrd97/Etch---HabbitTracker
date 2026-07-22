# Тема: FastAPI routing, 405 от wildcard и openapi-fetch unwrap

## Часть 1 — Как FastAPI собирает URL из prefix-ов

### Концепция

Каждый маршрут в FastAPI — результат сложения трёх частей: prefix в `app.include_router()`, prefix в `APIRouter()`, и path в декораторе `@router.get(path)`. Если любая из частей пропущена, реальный URL будет другим, чем ты ожидаешь.

Это не очевидно, потому что FastAPI не кричит при старте — сервис поднимается, `/health` отвечает, всё выглядит живым. Неправильный prefix обнаруживается только когда конкретный запрос не находит маршрут.

### Как это работает

```
app.include_router(router, prefix="/api/users")
                                    ↑
                              часть 1 (контекст монтирования)

APIRouter(prefix="/me")
              ↑
        часть 2 (группа роутов, обычно пустая в наших сервисах)

@router.get("/dashboard")
              ↑
        часть 3 (конкретный эндпоинт)

итог: GET /api/users/me/dashboard
```

Если `app.include_router(router)` без prefix → роуты будут `/me`, `/me/dashboard` и т.д. Запрос на `/api/users/me` не найдёт ничего.

### Код

❌ Роутер подключён без prefix — маршруты регистрируются на корне:

```python
# main.py
app.include_router(user_api_router)
# реальные маршруты: GET /me, PATCH /me, GET /me/settings
# фронт шлёт: GET /api/users/me → не совпадает
```

✅ Prefix задан явно — маршруты совпадают с тем, что ожидает фронт:

```python
# main.py
app.include_router(user_api_router, prefix="/api/users")
app.include_router(settings_router, prefix="/api/users/me/settings", tags=["users"])
# реальные маршруты: GET /api/users/me, GET /api/users/me/settings
```

### Подводные камни

Если в проекте есть `router.py` (orchestrator) и `main.py`, они могут монтировать один и тот же роутер с разными prefix-ами или вовсе без них. В этом проекте `router.py` не используется в `main.py` — сервис импортирует роутеры напрямую. Всегда смотри именно на `main.py`.

---

## Часть 2 — Почему 405, а не 404

### Концепция

`404 Not Found` — путь не совпал ни с одним маршрутом.
`405 Method Not Allowed` — путь совпал, но метод не тот.

Вторая ситуация может возникнуть там, где ты не ожидаешь: если в роутере есть wildcard-маршрут, он "поглощает" любой путь, и для методов, которые на нём не зарегистрированы, FastAPI возвращает 405.

### Как это работает

```
Запрос: GET /api/users/me

FastAPI перебирает маршруты:
  1. GET  /me            → путь не совпал
  2. PATCH /me           → путь не совпал
  3. OPTIONS /{path:path} → путь СОВПАЛ (wildcard)
                            метод OPTIONS ≠ GET
                            → 405 Method Not Allowed
```

Без wildcard шаг 3 не случился бы, и FastAPI вернул бы 404.

### Код

Wildcard OPTIONS-хендлер в `user_router.py` — сделан для CORS preflight, но как побочный эффект перехватывает все незарегистрированные пути:

```python
@router.options("/{path:path}", include_in_schema=False)
async def users_options(path: str = "") -> Response:
    return Response(status_code=204)
```

`/{path:path}` — специальный тип параметра в Starlette, совпадает с любым путём, включая вложенные слэши. Он работает как catch-all для метода OPTIONS.

### Подводные камни

Ошибка `405` на путь, который "не существует", — это сигнал о наличии wildcard-роута в роутере. Первым делом ищи `/{path:path}` или аналог в роутерах сервиса.

Диагностика по коду ответа:

| Код | Причина |
|---|---|
| 404 | Ни один маршрут не совпал по пути |
| 405 | Путь совпал (в т.ч. через wildcard), метод — нет |
| 422 | Маршрут нашёлся, но тело/параметры не прошли валидацию |

Быстрая диагностика: открой `/docs` на работающем сервисе — там виден полный список реальных зарегистрированных маршрутов.

---

## Часть 3 — openapi-fetch: обёртка, которая не бросает исключения

### Концепция

`openapi-fetch` — это типизированный HTTP-клиент, построенный поверх `fetch`. Его главное отличие от `axios` или обычного `fetch`: он **никогда не бросает исключение** на HTTP-ошибку и **никогда не возвращает данные напрямую**. Вместо этого он всегда возвращает объект-обёртку.

Это удобно для обработки ошибок, но создаёт ловушку: если сохранить результат вызова напрямую в state, данные окажутся на уровень глубже, чем ожидается.

### Как это работает

```
              openapi-fetch
┌──────────┐               ┌──────────────────────────────────┐
│  client  │ .GET("/me") → │  { data, error, response }       │
└──────────┘               │    data: ProfileResponse | undef │
                           │    error: ErrorObject | undef    │
                           │    response: Response            │
                           └──────────────────────────────────┘
```

Поток данных через компоненты в этом проекте:

```
auth-service /api/auth/me
      ↓
authClient.GET("/api/auth/me")  →  { data: UserResponse, error, response }
      ↓
CabinetShell.tsx: await authApi.getCurrentUser()
      ↓ (раньше сохраняли весь объект)
setAuthUser(u)   →  authUser = { data: UserResponse, error: null, response }
      ↓
ProfilePanel.tsx: authUser?.is_verified
      ↓
undefined  →  "NOT VERIFIED"
```

### Код

❌ Результат сохраняется в state без unwrap — `authUser` содержит обёртку, а не данные:

```ts
// CabinetShell.tsx
const [u, p] = await Promise.all([
  authApi.getCurrentUser(),
  userApi.getProfile(),
])
setAuthUser(u)  // u = { data: UserResponse, error: null, response: ... }
setProfile(p)   // p = { data: ProfileResponse, error: null, response: ... }

// ProfilePanel.tsx
authUser?.is_verified  // → undefined (поля нет на объекте-обёртке)
authUser?.is_active    // → undefined
// рендерится: "NOT VERIFIED" | "INACTIVE"
```

✅ Делаем unwrap `.data` и проверяем `.error` перед сохранением:

```ts
// CabinetShell.tsx
const [uRes, pRes] = await Promise.all([
  authApi.getCurrentUser(),
  userApi.getProfile(),
])
if (uRes.error) throw new Error(String(uRes.response.status))
if (pRes.error) throw new Error(String(pRes.response.status))
setAuthUser(uRes.data ?? null)  // теперь UserResponse
setProfile(pRes.data ?? null)   // теперь ProfileResponse

// ProfilePanel.tsx
authUser?.is_verified  // → true/false (реальное значение)
```

Канонический паттерн для любого вызова openapi-fetch:

```ts
const { data, error } = await client.GET("/some/endpoint")
if (error) throw new Error(...)
// работай с data
```

### Подводные камни

TypeScript не всегда ловит это несоответствие. Если `authApi.getCurrentUser()` возвращает `Promise<FetchResponse<UserResponse>>`, а стейт типизирован как `UserResponse | null`, TypeScript должен ругаться — но в реальности он промолчал, потому что где-то в цепочке потерялась строгость типов (вероятно, `any` в return type одной из функций).

Вывод: не полагайся на TS как на единственную защиту. Всегда явно деструктурируй `{ data, error }` — это самодокументирующий код, который невозможно случайно использовать неправильно.

---

## Чеклист

- [ ] В `main.py` у каждого `app.include_router()` указан явный `prefix`, соответствующий путям в openapi-types фронта
- [ ] После запуска сервиса проверить `/docs` — убедиться, что маршруты на нужных путях
- [ ] При 405 на "несуществующий" путь — искать wildcard `/{path:path}` в роутерах
- [ ] Каждый вызов openapi-fetch деструктурируется: `const { data, error } = await client.GET(...)`
- [ ] Перед использованием `data` проверяется `error`
- [ ] В state сохраняется только `.data`, никогда не весь response-объект
