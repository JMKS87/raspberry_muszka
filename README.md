# Muszka Instruct 1.5B (Q6_K) na Raspberry Pi 5

Gotowy setup polskiego modelu [Muszka Instruct 1.5B v1.0](https://muszkaowocowa.pl/muszka-instruct/)
w kwantyzacji **Q6_K** (1,31 GB), uruchamianego w Dockerze przez `llama-server` z
[llama.cpp](https://github.com/ggml-org/llama.cpp).

Jeden kontener wystawia na jednym porcie:

- **czat WWW**: `http://<ip-pi>:8080`, dostępny z każdego urządzenia w sieci lokalnej,
- **API zgodne z OpenAI**: `http://<ip-pi>:8080/v1/...`.

| | |
|---|---|
| Model | `Fibogacci/muszka-instruct-1.5b-v1.0-GGUF` → `muszka-instruct-1.5b-v1.0-Q6_K.gguf` |
| Bazuje na | Bielik-1.5B-v3.0-Instruct (SpeakLeash) |
| Kontekst | 8192 tokeny na slot |
| Format czatu | ChatML (szablon wbudowany w GGUF) |
| Licencja | Apache 2.0 |

## Wymagania

- Raspberry Pi 5 (testowane założenia: 8 GB RAM)
- **64-bitowy** Raspberry Pi OS (Bookworm lub nowszy)
- Docker + plugin compose:
  ```bash
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER   # wyloguj się i zaloguj ponownie
  ```
- ok. 1,5 GB wolnego miejsca na model

## Uruchomienie

```bash
git clone <repozytorium> raspberry_muszka
cd raspberry_muszka

cp .env.example .env
nano .env                          # ustaw API_KEY, PARALLEL itd.

bash scripts/download-model.sh     # pobiera model i sprawdza SHA-256
docker compose up -d
docker compose logs -f             # poczekaj na "server is listening"
```

Test:

```bash
bash scripts/test-api.sh
```

Adres IP Pi sprawdzisz poleceniem `hostname -I`.

## Konfiguracja (`.env`)

| Zmienna | Domyślnie | Opis |
|---|---|---|
| `LLAMA_CPP_IMAGE` | `ghcr.io/ggml-org/llama.cpp:server` | Obraz serwera. Najlepiej przypiąć konkretny build (`server-bXXXX`). |
| `MODEL_FILE` | `muszka-instruct-1.5b-v1.0-Q6_K.gguf` | Plik w `models/` |
| `BIND_ADDRESS` | `0.0.0.0` | Interfejs, na którym nasłuchuje port |
| `MUSZKA_PORT` | `8080` | Port WWW i API |
| `API_KEY` | *(pusty)* | Klucz Bearer do API. Pusty oznacza brak autoryzacji. |
| `THREADS` | `2` | Wątki CPU. Wartość dobierzesz skryptem `bench.sh`. |
| `PARALLEL` | `2` | Liczba równoległych użytkowników (slotów) |
| `CTX_PER_SLOT` | `8192` | Kontekst na slot. Nie przekraczaj 8192. |
| `MEM_LIMIT` | `4g` | Limit RAM kontenera |
| `TEMPERATURE` / `TOP_P` / `REPEAT_PENALTY` | `0.2` / `0.9` / `1.05` | Domyślne próbkowanie (zalecenia autora modelu) |

Po zmianie `.env` uruchom `docker compose up -d`. Kontener zostanie odtworzony.

### Liczba użytkowników (`PARALLEL`)

Serwer obsługuje `PARALLEL` zapytań jednocześnie. Każdy slot ma własny kontekst
`CTX_PER_SLOT`, a kontekst całkowity (`CTX_PER_SLOT × PARALLEL`) liczy się automatycznie.
Każde zapytanie ponad limit czeka w kolejce.

- Pamięć nie jest ograniczeniem. KV cache dla modelu 1.5B przy 8k tokenów zajmuje kilkaset MB,
  więc na Pi 5 8 GB zmieści się kilka slotów. Przy dużej liczbie slotów podnieś `MEM_LIMIT`.
- Ograniczeniem jest CPU i przepustowość RAM. Równoczesne zapytania dzielą moc,
  więc dwa naraz generują wolniej niż jedno. Dla domowego użytku rozsądne jest 1–4 slotów.

## Interfejs WWW

Otwórz `http://<ip-pi>:8080` w przeglądarce. Jeśli ustawiłeś `API_KEY`, wpisz go
w ustawieniach interfejsu (ikona zębatki → API Key).

## API

Endpointy zgodne z OpenAI: `/v1/chat/completions`, `/v1/completions`, `/v1/models`
(ze streamingiem). Endpoint `/health` nie wymaga klucza.

### curl

```bash
curl http://<ip-pi>:8080/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "muszka-instruct",
    "messages": [{"role": "user", "content": "Napisz krótki wierszyk o kocie."}],
    "max_tokens": 200
  }'
```

### Python (`pip install openai`)

```python
from openai import OpenAI

client = OpenAI(base_url="http://<ip-pi>:8080/v1", api_key="TWOJ_API_KEY")

stream = client.chat.completions.create(
    model="muszka-instruct",
    messages=[
        {"role": "system", "content": "Jesteś pomocnym asystentem."},
        {"role": "user", "content": "Jak zrobić kompost?"},
    ],
    temperature=0.3,
    stream=True,
)
for chunk in stream:
    print(chunk.choices[0].delta.content or "", end="", flush=True)
```

Jeśli `API_KEY` jest pusty, jako `api_key` podaj dowolny niepusty tekst.

## Wydajność

```bash
docker compose stop
bash scripts/bench.sh 1,2,3,4      # llama-bench dla różnych liczb wątków
docker compose start
```

Wynik `tg` (tokeny/s generowania) wskazuje najlepszą wartość `THREADS`. Autor modelu
podaje, że na Pi 5 najszybsze jest `-t 2` (ok. 12 tok/s dla Q4_K_M). Q6_K będzie
nieco wolniejszy. Skrypt pobiera dodatkowo obraz `llama.cpp:full`.

Wskazówki:
- Używaj aktywnego chłodzenia (Active Cooler), bo bez niego Pi 5 zwalnia przez throttling.
- Kwantyzacje **Q4_0 i Q8_0** według autora dają na Pi 5 nieczytelny tekst. Używaj K-quantów
  (Q4_K_M / Q5_K_M / Q6_K).

## Bezpieczeństwo

- Ustaw `API_KEY`, jeśli w sieci są inne osoby lub urządzenia.
- **Nie przekierowuj portu na routerze.** Setup jest przeznaczony tylko do sieci lokalnej.
- Model nie ma dodatkowego dostrajania bezpieczeństwa. Autor sugeruje filtr wejścia
  [Muszka Guard](https://muszkaowocowa.pl/muszka-guard/).
- Model słabo zna fakty. Do zadań wymagających wiedzy autor zaleca RAG.

## Utrzymanie

```bash
docker compose pull && docker compose up -d   # aktualizacja llama.cpp
docker compose logs -f                        # logi
docker compose ps                             # status i healthcheck
docker compose down                           # zatrzymanie
```

Kontener startuje automatycznie po restarcie Pi (`restart: unless-stopped`).

## Struktura

```
docker-compose.yml        usługa llama-server
.env.example              wzór konfiguracji
scripts/download-model.sh pobranie modelu (przypięta rewizja HF + SHA-256)
scripts/test-api.sh       test /health, /v1/models i czatu
scripts/bench.sh          benchmark wątków (llama-bench)
models/                   pliki .gguf (poza gitem)
```
