# 💡 IT Ciekawostki Portal

**Stack:** Node.js 20 · PostgreSQL 16 · Redis 7 · Bull Queue · EJS  
**Port:** `7125`

---

## ⚡ Wdrożenie w Coolify (w pełni automatyczne)

### Krok 1 – Dodaj zasób

Coolify → **Resources → New → Docker Compose**

Wskaż repozytorium GitHub i plik `docker-compose.yml`.  
Coolify automatycznie zbuduje obraz aplikacji, uruchomi PostgreSQL i Redis.

### Krok 2 – Ustaw tylko 2 zmienne środowiskowe

W panelu Coolify → zakładka **Environment Variables** dodaj:

| Zmienna | Wartość |
|---|---|
| `POSTGRES_PASSWORD` | silne hasło (np. wygeneruj losowe) |
| `SESSION_SECRET` | losowy string min. 32 znaki |

Pozostałe (`DATABASE_URL`, `REDIS_URL`, `PORT`, `NODE_ENV`) są **automatycznie** ustawiane przez `docker-compose.yml` na podstawie wewnętrznych nazw serwisów.

### Krok 3 – Deploy

Kliknij **Deploy**. Coolify:
1. Buduje obraz Node.js 20 z `Dockerfile`
2. Startuje PostgreSQL 16 z healthcheckiem
3. Startuje Redis 7 z healthcheckiem
4. **Automatycznie ładuje `db/init.sql`** → schemat + 10 artykułów seed
5. Startuje aplikację dopiero gdy oba serwisy są gotowe

**Żadnych ręcznych kroków w SQL ani ręcznego tworzenia bazy.**

---

## Lokalne uruchomienie

```bash
cp .env.example .env
# Uzupełnij POSTGRES_PASSWORD i SESSION_SECRET w .env
docker-compose up -d
# Aplikacja dostępna na http://localhost:7125
```

---

## Architektura

```
┌─────────────────────────────────────────┐
│            docker-compose               │
│                                         │
│  ┌─────────┐   healthy?  ┌──────────┐  │
│  │PostgreSQL│◄────────── │   App    │  │
│  │  :5432   │            │  :7125   │  │
│  └─────────┘            └──────────┘  │
│       ↑ init.sql auto                   │
│  ┌─────────┐   healthy?       ↑        │
│  │  Redis  │◄─────────────────┘        │
│  │  :6379  │  sessions + Bull Queue     │
│  └─────────┘                            │
└─────────────────────────────────────────┘
```

## Funkcje

- 📚 Artykuły IT z kategoriami, tagami, paginacją
- 👤 Rejestracja / logowanie (bcrypt + Redis sessions)
- 📬 Newsletter (zapis/wypis kolejkowany przez Bull → Redis)
- 👥 System znajomych (zaproszenia, akceptacja, profil)
- ❤️ Like'i i komentarze do artykułów (AJAX)
- 🌙 Dark/Light mode
- 🔒 Rate limiting, Helmet, express-validator
