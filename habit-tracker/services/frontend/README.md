# Habit Tracker Frontend

Modern, responsive web application for tracking habits built with Next.js 16, Bun, and TailwindCSS.

## Features

- 📊 **Dashboard** - Overview of your tracking stats
- 📁 **Categories** - Create and manage custom tracking categories with dynamic fields
- 📝 **Entries** - Log daily data for your categories
- 📖 **Journal** - Write daily journal entries with mood tracking
- 🎨 **Modern UI** - Clean, responsive design with TailwindCSS
- ⚡ **Fast** - Built with Next.js App Router and Bun runtime

## Tech Stack

- **Framework**: Next.js 16 (App Router)
- **Runtime**: Bun
- **Language**: TypeScript
- **Styling**: TailwindCSS 4.x
- **Icons**: Lucide React
- **API Client**: Native Fetch API

## Getting Started

### Prerequisites

- Bun 1.3+ installed
- Backend API running on http://localhost:8000

### Development

```bash
# Install dependencies
bun install

# Run development server
bun dev

# Open browser
# http://localhost:3000
```

### Production Build

```bash
# Build for production
bun run build

# Start production server
bun start
```

### Docker

```bash
# Build and run with Docker Compose
docker-compose up --build frontend

# Access at http://localhost:3000
```

## Project Structure

```
frontend/
├── app/
│   ├── page.tsx              # Dashboard
│   ├── categories/page.tsx   # Categories management
│   ├── entries/page.tsx      # Entries tracking
│   ├── journal/page.tsx      # Journal entries
│   ├── layout.tsx            # Root layout
│   └── globals.css           # Global styles
├── components/
│   ├── Navigation.tsx        # Main navigation
│   ├── LoadingSpinner.tsx    # Loading indicator
│   └── ErrorAlert.tsx        # Error messages
├── lib/
│   └── api.ts                # API client & types
└── public/                   # Static assets
```

## API Integration

The frontend connects to the backend API via environment variables:

```env
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1
```

All API calls are handled through the `lib/api.ts` module with:
- Type-safe interfaces
- Error handling
- Automatic JSON serialization

## Features in Detail

### Categories
- Create categories with custom fields
- Support for multiple field types (text, number, date, select, etc.)
- Color coding for visual organization
- Edit and delete capabilities

### Entries
- Quick data entry forms
- Dynamic fields based on selected category
- Filter by category
- Date-based tracking

### Journal
- Rich text journal entries
- Mood tracking with emojis
- Tag support
- Full CRUD operations

### Dashboard
- Quick stats overview
- Recent activity feed
- Quick action buttons
- Category and entry counts

## Environment Variables

- `NEXT_PUBLIC_API_URL` - Backend API URL (default: http://localhost:8000/api/v1)

## License

MIT
