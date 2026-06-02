# SeleniumOrchestratorStack — yapı ve işletim

Bu klasör, **SeleniumOrchestrator** ortamını Docker Compose ile ayağa kaldırmak için kullanılan stack tanımlarını ve yardımcı scriptleri içerir.

## Klasör yapısı (özet)

| Yol | Açıklama |
|-----|----------|
| `definitions.env` | Tüm ortamlarda ortak sabitler (sunucu yolları, `PROJECT_TITLE`, ağ adı, DB kullanıcıları, Git remote’lar vb.) |
| `definitions.test.env` | Sadece **test** ortamına özel (dal, API URL, `DEPLOY_ENV=test`, `KEYCLOAK_REALM` …) |
| `definitions.prod.env` | Sadece **prod** ortamına özel |
| `docker-compose.base.yml` | Tüm ortak servisler |
| `seleniumorchestrator-test/docker-compose.yml` | Test’e özel override (ör. listmonk) |
| `seleniumorchestrator-prod/docker-compose.yml` | Prod’a özel override (ör. `FrontendReact` healthcheck, listmonk) |
| `lib/load-definitions.sh` | Bash scriptlerinde env değişkenlerini yükler |
| `lib/compose.sh` | `olustur_compose` fonksiyonu — uzun `docker compose` komutunu tek satırda toplar |

Uygulama kaynak kodu bu repoda değildir; `definitions.env` içindeki `APP_SOURCE_DIR` (ör. `/home/devops/source/seleniumorchestrator`) uygulama reposunu işaret eder.

---

## `definitions` nedir?

**Definitions**, Compose ve scriptlerin okuduğu **ortam değişkeni dosyaları**dır.

1. **`definitions.env`** — Her zaman yüklenir. `PROJECT_TITLE`, `DEVOPS_HOME`, **`VOLUME_ROOT`** (Docker volume’ların host’taki tek kökü, genelde `${DEVOPS_HOME}/volumes/${PROJECT_TITLE}`), `NETWORK_NAME`, ortak sırlar / DB kullanıcı adları gibi değerler burada.
2. **`definitions.test.env`** veya **`definitions.prod.env`** — Ortam seçimine göre ikinci dosya; `olustur_compose test|prod` ve `source load-definitions.sh test|prod` bunlardan birini yükler.

Compose tarafında:

```bash
docker compose \
  --env-file definitions.env \
  --env-file definitions.test.env   # veya definitions.prod.env
```

Bash tarafında script başında:

```bash
source "${SCRIPT_DIR}/lib/load-definitions.sh" test   # veya prod
source "${SCRIPT_DIR}/lib/compose.sh"
```

---

## Shell scriptleri ne işe yarar?

| Script | Görev |
|--------|--------|
| `lib/compose.sh` | **`olustur_compose test|prod <komut>`** — `docker-compose.base.yml` + `seleniumorchestrator-{test\|prod}/docker-compose.yml` ve doğru `--env-file` ile çalıştırır. `--project-name "${PROJECT_TITLE}-${env}"` ile konteyner adları tutarlı kalır. |
| `lib/load-definitions.sh` | `definitions.env` → isteğe bağlı `test` veya `prod` katmanı; `APP_SOURCE_DIR`, `STACK_SOURCE_DIR`, yedek değişkenleri vb. bash’te kullanılır. |
| `ac.sh` | Test ve prod stack’i **ayaga kaldırır** (`up -d`). |
| `kapat.sh` | Test ve prod stack’i **durdurur** (`down`). |
| `ackapat.sh` | Önce `down`, sonra tekrar `up -d` (yeniden başlatma). |
| `surum-test.sh` | Uygulama reposunda git güncelleme, imaj build (backend, frontend, yardım), genel servisler, sonra **`olustur_compose test up -d`**. |
| `surum-prod.sh` | Prod için aynı mantık. |
| `surum.sh` | Stack reposunu günceller, ardından `surum-test.sh` ve `surum-prod.sh` çalıştırır. |
| `getgit_stack.sh` / `getgit_source.sh` | İlgili repoları sunucuya çekmek için. |
| `surum-genel-servisler.sh` | Ortak servis imajları (rota, sms, llm vb.) ve Keycloak tema/SPI gibi işler. |
| `backup-postgres-test.sh` / `backup-postgres-prod.sh` | PostgreSQL yedeği; `load-definitions.sh` ile yedek dizini ve konteyner adını alır. |

---

## Yeni servis eklerken yapılacaklar

Aşağıdaki sıra tipik bir ekleme içindir; servis her ortamda aynıysa **`docker-compose.base.yml`** içine, sadece bir ortamda farklıysa ilgili **`seleniumorchestrator-test/docker-compose.yml`** veya **`seleniumorchestrator-prod/docker-compose.yml`** içine yazın.

### 1. Compose tanımı

- **Ortak davranış** → `docker-compose.base.yml` içinde yeni `services:` girdisi.
- **Sadece test veya sadece prod** → ilgili override dosyasında aynı servis adıyla ek alanlar (Compose birleştirir).
- Ağ: Stack’teki diğer servislerle konuşacaksa **`appNetwork`** (`NETWORK_NAME` ile `seleniumorchestratorNetwork`) kullanın; host’a port açmayacaksanız `ports:` yazmayın (edge nginx üzerinden erişim).

### 2. Ortam değişkenleri

- Tüm ortamlarda aynı sabit → `definitions.env`.
- Test / prod’a göre değişen (URL, realm, `DEPLOY_ENV` ile ilgili olmayan her şey) → `definitions.test.env` / `definitions.prod.env`.
- Compose içinde `${DEGISKEN}` kullanıyorsanız, değişken bu dosyalardan birinde tanımlı olmalı.

### 3. Imaj build gerekiyorsa

- `surum-test.sh` ve/veya `surum-prod.sh` içine, diğer servislerde olduğu gibi **`docker build`** satırı ekleyin (doğru `Dockerfile` ve `-t` etiketi, genelde `${PROJECT_TITLE}-...-${DEPLOY_ENV}` kalıbı).
- Compose’da bu imaja **`image:`** ile referans verin.

### 4. İsimlendirme

- Konteyner / DNS: `--project-name` sayesinde servis adı `keycloak` ise konteyner örneği `seleniumorchestrator-test-keycloak-1` biçimindedir; servisler arası erişimde bu adları veya Compose **servis adını** kullanın.
- `KEYCLOAK_REALM` gibi tüm uygulamanın ortak kullandığı değerler tek isimle (`KEYCLOAK_REALM`) `definitions.<env>.env` içinde tutulur.

### 5. Doğrulama

```bash
cd /path/to/SeleniumOrchestratorStack
source lib/load-definitions.sh test
source lib/compose.sh
olustur_compose test config   # birleşik config'i görmek için
```

---

## Kısa hatırlatma

- **Compose**, `--env-file` ile gelen değişkenleri YAML içinde `${VAR}` olarak genişletir; `definitions.env` içinde iç içe `${PROJECT_TITLE}` kullanımı bu yüzden çalışır.
- **Sırlar** mümkünse dış secret yönetimine taşınmalıdır.
- Bu README **SeleniumOrchestratorStack**’e özeldir; aynı düzeni başka ürün stack’lerine kopyalarken servis listesi ve path’leri o ürüne göre güncellenmelidir.