# RSBD - Projekt
### Autorzy: Jakub Jaśków, Justyna Ziemichód (G2)

## Instrukcja:

Aby poniższe instrukcje zadziałały muszą one zostać wykonane z wewnątrz folderu `src/`.

1. Start
```
docker compose up -d
```
2. Stop
```
docker compose down
```
3. Twardy reset (usunięcie wolumenów / bazy danych)
```
docker compose down -v
```
4. Połączenie z postgresem
```
psql -h localhost -U primary
```

## Terminarz:
- [x] **Zajęcia 1 - 7.10.2025:**
Sprawy organizacyjne; bhp; ustalanie składu i numerów grup projektowych; w
kolejnych tygodniach grupy o numerach nieparzystych przychodzą na zajęcia o numerach
nieparzystych, tj. 3, 5, 7, 9, 11, 13, a także na zajęcia 14 i 15, a grupy o numerach
parzystych przychodzą na zajęciach o numerach parzystych, tj. 2, 4, 6, 8, 10, 12, a także na
zajęcia 14 i 15 (uwaga: jeśli grupa nie może przyjść na swój termin lub termin wypadnie z
powodu, np. godzin rektorskich lub innych, to można przyjść w kolejnym tygodniu).

- [x] **Zajęcia 2 - 14.10.2025, 4 - 28.10.2025:**
analiza literaturowa, definiowanie tematów i wstępnych założeń
projektowych

- [x] **Zajęcia 6 - 10.11.2025:** 
Przesłanie sprawdzonej, finalnej wersji opisu założeń do projektu (według
podanego wzoru) na maila prowadzącego; prezentacja wymagań funkcjonalnych i
niefunkcjonalnych rozproszonej aplikacji bazodanowej – diagram przypadków użycia,
wybrane scenariusze użycia

- [x] **Zajęcia 8 - 25.11.2025:**
Testowanie mechanizmów replikacji i/lub rozpraszania danych w wybranych
środowiskach bazodanowych (np. PostgreSQL) oraz środowiskach wirtualizacji (np.
Docker, Kubernetes);

- [x] **Zajęcia 10 - 9.12.2025:**
Projekt i implementacja rozproszonej bazy danych

- [ ] **Zajęcia 12 - 13.01.2026:**
Projekt i implementacja prostej aplikacji wykorzystującej rozproszoną bazę
danych; projekt oraz implementacja mechanizmów loadbalancingu (np. HAProxy, Nginx),
zapewniających wysoką dostępność systemu oraz równoważenie obciążenia serwerów
bazodanowych i/lub serwerów aplikacji

- [ ] **Zajęcia 14 - 27.01.2026:**
Testy i ocena działania systemu rozproszonego; prezentacja działania
aplikacji, spisu treści i/lub wstępnej wersji sprawozdania z projektu

- [ ] **Zajęcia 15 - 3.02.2026:**
Testy i ocena działania systemu rozproszonego; prezentacja
działania aplikacji, spisu treści i/lub wstępnej wersji sprawozdania z projektu;
