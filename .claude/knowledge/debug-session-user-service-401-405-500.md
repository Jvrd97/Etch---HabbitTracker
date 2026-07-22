# Debug: user-service "NOT VERIFIED / INACTIVE" — цепочка из 4 багов

Симптом на фронте: `NOT VERIFIED | INACTIVE` на странице профиля.
Симптом в логах: `GET /api/users/me` → 405, потом 401, потом 500.
Каждый фикс открывал следующий баг. Цепочка:

```
405 → openapi-fetch unwrap fix → 401 (?) → prefix fix → 500 → list→int fix → 200 ✓
```

---

## Баг 1 — openapi-fetch: результат не разворачивается из обёртки

**Файл:** `frontend/src/pages/cabinet/CabinetShell.tsx`

`openapi-fetch` всегда возвращает `{ data, error, response }` — никогда не сырые данные.
В `reloadProfile` результат сохранялся напрямую в state без `.data`.

```ts
// ❌ БЫЛО
const [u, p] = await Promise.all([authApi.getCurrentUser(), userApi.getProfile()])
setAuthUser(u)   // u = { data: UserResponse, error: null, response: ... }
setProfile(p)

// в ProfilePanel.tsx:
authUser?.is_verified  // → undefined → "NOT VERIFIED"
authUser?.is_active    // → undefined → "INACTIVE"
```

```ts
// ✅ СТАЛО
const [uRes, pRes] = await Promise.all([authApi.getCurrentUser(), userApi.getProfile()])
if (uRes.error) throw new Error(String(uRes.response.status))
if (pRes.error) throw new Error(String(pRes.response.status))
setAuthUser(uRes.data ?? null)
setProfile(pRes.data ?? null)
```

**Правило:** всегда деструктурируй `{ data, error }` из openapi-fetch. Никогда не сохраняй весь response в state.

---

## Баг 2 — FastAPI: роутер подключён без prefix

**Файл:** `backend/services/user-service/main.py`

Маршруты в `user_api_router` объявлены как `/me`, `/me/preferences/{channel}` и т.д.
Без prefix они монтируются на корне: реальный путь — `/me`, а фронт шлёт `/api/users/me`.

```python
# ❌ БЫЛО
app.include_router(user_api_router)   # routes at /me, /me/settings...

# ✅ СТАЛО
app.include_router(user_api_router, prefix="/api/users")
app.include_router(settings_router, prefix="/api/users/me/settings", tags=["users"])
```

**Правило:** после добавления роутера — открыть `/docs` и убедиться, что маршруты по нужным путям.

---

## Баг 3 — FastAPI: catch-all OPTIONS даёт 405 вместо 404

**Файл:** `backend/services/user-service/app/api/router/public/user_router.py`

В роутере был catch-all для CORS preflight:

```python
@router.options("/{path:path}", include_in_schema=False)
async def users_options(path: str = "") -> Response:
    return Response(status_code=204)
```

`/{path:path}` совпадает с любым путём, включая `/api/users/me`.
FastAPI нашёл совпадение по пути, но метод `GET` не зарегистрирован → **405**, а не 404.

Пока prefix отсутствовал, этот wildcard "поглощал" все запросы на несуществующие пути.
После добавления правильного prefix в Баге 2 — конкретные маршруты стали приоритетнее wildcard, и 405 ушёл.

**Диагностика:**

| Код | Причина |
|---|---|
| 404 | Ни один маршрут не совпал |
| 405 | Путь совпал (в т.ч. через wildcard), метод — нет |
| 422 | Маршрут нашёлся, тело/параметры не прошли валидацию |

---

## Баг 4 — `expected_roles: list[int]` передаётся туда, где ожидается `int`

**Файл:** `backend/services/user-service/app/api/router/public/dependencies/dependencies.py`

`settings.expected_roles` — это `list[int]` (битовые флаги из конфига).
Передавался напрямую в `get_current_user(settings, expected_role_flags=expected_roles)`,
где параметр имеет тип `int`.

Внутри `check_expected_role` → `has_role(user.role_flags, expected_role_flags)`:

```python
return (user_flags & required_flags) != 0
#        RoleFlags  &      list        → TypeError
```

```
TypeError: unsupported operand type(s) for &: 'RoleFlags' and 'list'
→ 500 Internal Server Error
```

```python
# ❌ БЫЛО
expected_roles = settings.expected_roles if settings.expected_roles else {}
require_user = get_current_user(settings, expected_role_flags=expected_roles)

# ✅ СТАЛО — свести список в единый bitmask через OR
_role_flags: int = 0
for _flag in settings.expected_roles:
    _role_flags |= _flag
require_user = get_current_user(settings, expected_role_flags=_role_flags)
```

**Почему не поймал mypy:** `get_current_user` принимает `expected_role_flags: int = 0`,
но `settings.expected_roles` типизирован как `list[int]` — присваивание в переменную без аннотации
дало тип `list[int]`, а `int & list[int]` в mypy --strict должен ловиться.
Баг прожил, потому что до него не доходили (Баги 2 и 3 срабатывали раньше).

---

## Итоговая карта потока данных

```
Браузер
  └─ POST /api/auth/login → auth-service:8001 → { access_token }
       → localStorage.setItem("access_token", ...)

  └─ GET /api/auth/me     → auth-service:8001  → 200 UserResponse
  └─ GET /api/users/me    → user-service:8002  → 200 ProfileResponse

user-service auth pipeline:
  Bearer token
    └─ alvion_core.dependencies.get_current_user(settings, expected_role_flags=int)
         ├─ jwt.decode(token, jwt_secret_key)  ← должен совпадать с auth-service
         ├─ UUID(payload["sub"])
         └─ check_expected_role(user, bitmask_int)
               └─ has_role(user.role_flags & required_flags)
```

---

## Чеклист при добавлении нового сервиса / роутера

- [ ] `app.include_router(router, prefix="/api/xxx")` — prefix задан явно
- [ ] Открыть `/docs` после старта — убедиться что маршруты по нужным путям
- [ ] `jwt_secret_key` в `.env` сервиса совпадает с тем, кто выпускает токены
- [ ] `expected_role_flags` передаётся как `int` (bitmask), не как `list`
- [ ] openapi-fetch: `const { data, error } = await client.GET(...)` — всегда деструктурировать
- [ ] Не сохранять весь FetchResponse в state — только `.data`
