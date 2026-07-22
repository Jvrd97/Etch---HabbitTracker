# Дизайн-система «Lime Tech»

Канон для всех клиентов (web-админка, iOS). Референс-мокапы: `refs/ref.png`. Утверждена пользователем 2026-07-22.

## Идея

Не «милый wellness», а операционная система организма: строгий технологичный интерфейс, ощущение дорогого прибора. Вдохновение: Whoop, Linear, Arc, Nothing, Raycast, DevTools.

## Палитра

| Токен | Значение |
|---|---|
| background | `#090909` |
| surface | `#141414` |
| card (elevated) | `#1A1A1A` |
| primary (lime) | `#B8FF36` |
| secondary green | `#69E76A` |
| text primary | `#FFFFFF` |
| text secondary | `#A3A3A3` |
| text disabled | `#666666` |
| success | `#4ADE80` |
| warning | `#FACC15` |
| danger | `#EF4444` |
| info | `#60A5FA` |

## Стиль

- Dark UI, glass + matte, скругления 20–28 px, много воздуха, минимум градиентов, без декоративных иллюстраций.
- Типографика: SF Pro Display (iOS) / Inter (web). H1 36 Bold, Section 22 Semibold, Card 18 Medium, Body 16 Regular, Caption 13 Medium.
- Иконки: SF Symbols (iOS) / Lucide (web), stroke 2px.
- Акцент — лайм: активный таб, primary-кнопки, прогресс-кольца, свечение при завершении привычки.

## Ключевые паттерны (из ref.png)

- Навигация: нижний tab bar (iOS) / верхняя навигация (web) — Dashboard, Today, Table, Journal, Settings; активный пункт лаймовый.
- Dashboard: hero-карточка Health Score с круговой диаграммой, 4 KPI, recent activity, quick actions.
- Today: календарная лента сверху, карточки привычек с круговым прогрессом и кнопкой «+».
- Table: grid в духе GitHub Contributions — интенсивность цвета ячейки от значения, тап → детали дня.
- Journal: timeline-карточки с эмоцией, тегами, превью; поиск и фильтр сверху.
- Quick Entry: bottom sheet ~70%, крупное число, быстрые кнопки (+100/+250/+500), для булевых — большой переключатель, для select — chips.
- Системные состояния: offline-баннер «Last sync HH:MM», зелёный бейдж «N changes waiting», empty state с одной кнопкой, error с Retry, loading — тонкое неоновое кольцо (не спиннер).

## Анимации

Живой, но спокойный интерфейс: подъём карточек при касании (2–4 px), дорисовка прогресс-колец 400–600 мс, сжатие+свечение при выполнении привычки, пружинный bottom sheet, fade+slide на смене вкладок, постепенная анимация графиков, haptic + зелёный check после синка.
