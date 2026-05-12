CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  display_name VARCHAR(100),
  bio TEXT,
  role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user','admin','editor')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS newsletter_subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL,
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','unsubscribed','pending')),
  subscribed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS friendships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined','blocked')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(requester_id,receiver_id),
  CHECK(requester_id <> receiver_id)
);

CREATE TABLE IF NOT EXISTS articles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title VARCHAR(300) NOT NULL,
  slug VARCHAR(300) UNIQUE NOT NULL,
  excerpt TEXT,
  content TEXT NOT NULL,
  category VARCHAR(50) DEFAULT 'general',
  tags TEXT[] DEFAULT '{}',
  author_id UUID REFERENCES users(id) ON DELETE SET NULL,
  views INTEGER DEFAULT 0,
  is_published BOOLEAN DEFAULT true,
  cover_emoji VARCHAR(10) DEFAULT '💡',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS article_likes (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY(user_id,article_id)
);

CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_articles_pub ON articles(is_published,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_cat ON articles(category);
CREATE INDEX IF NOT EXISTS idx_fs_recv ON friendships(receiver_id,status);
CREATE INDEX IF NOT EXISTS idx_fs_req ON friendships(requester_id,status);
CREATE INDEX IF NOT EXISTS idx_comments_art ON comments(article_id,created_at);

CREATE OR REPLACE FUNCTION update_updated_at() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at=NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_users_upd') THEN CREATE TRIGGER trg_users_upd BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at(); END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_art_upd') THEN CREATE TRIGGER trg_art_upd BEFORE UPDATE ON articles FOR EACH ROW EXECUTE FUNCTION update_updated_at(); END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_fs_upd') THEN CREATE TRIGGER trg_fs_upd BEFORE UPDATE ON friendships FOR EACH ROW EXECUTE FUNCTION update_updated_at(); END IF;
END $$;

INSERT INTO articles(title,slug,excerpt,content,category,tags,cover_emoji) VALUES
('Jak działa DNS – od A do Z','jak-dziala-dns','DNS to książka telefoniczna Internetu. Resolver, root serwery i TTL w jednym miejscu.','<h2>Czym jest DNS?</h2><p>System DNS (Domain Name System) jest fundamentem Internetu. Każda wpisana nazwa domeny musi zostać przetłumaczona na adres IP.</p><h2>Przebieg zapytania</h2><p>System sprawdza lokalny cache → resolver ISP → root serwery DNS → serwery TLD → autorytarne NS domeny.</p><h2>Typy rekordów</h2><ul><li><strong>A</strong> – IPv4</li><li><strong>AAAA</strong> – IPv6</li><li><strong>CNAME</strong> – alias</li><li><strong>MX</strong> – poczta</li><li><strong>TXT</strong> – SPF/DKIM</li></ul>','networking',ARRAY['dns','networking'],'🌐'),
('Kubernetes vs Docker Swarm','kubernetes-vs-docker-swarm','Kiedy Kubernetes, a kiedy Swarm? Praktyczne porównanie.','<h2>Docker Swarm</h2><p>Inicjalizacja: <code>docker swarm init</code>. Prostota konfiguracji, idealny dla małych wdrożeń.</p><h2>Kubernetes</h2><p>De facto standard w enterprise. HPA, VPA, KEDA, network policies, Helm, Flux, ArgoCD.</p><h2>Wybór</h2><ul><li><strong>Swarm</strong> – małe zespoły, prosta infrastruktura</li><li><strong>K8s</strong> – enterprise, złożone CI/CD, duże skalowanie</li></ul>','devops',ARRAY['kubernetes','docker','devops'],'⚙️'),
('PostgreSQL – indeksy które zmienią życie DBA','postgresql-indeksy','Partial, covering, expression indexes – optymalizacje od razu do produkcji.','<h2>Partial Index</h2><p><code>CREATE INDEX idx ON users(email) WHERE is_active=true;</code></p><h2>Covering (INCLUDE)</h2><p><code>CREATE INDEX idx ON articles(created_at DESC) INCLUDE(title,excerpt);</code><br>Index-only scan bez odczytu tabeli.</p><h2>Expression Index</h2><p><code>CREATE INDEX idx ON users(lower(email));</code> – case-insensitive wyszukiwanie.</p><h2>Diagnostyka</h2><p><code>EXPLAIN (ANALYZE, BUFFERS) SELECT ...</code></p>','databases',ARRAY['postgresql','performance','sql'],'🐘'),
('Redis – więcej niż cache','redis-struktury-danych','Strings, Sorted Sets, Streams, Pub/Sub – pełne spektrum możliwości Redis.','<h2>Strings</h2><p>Atomowe INCR/SETNX do liczników i distributed locking.</p><h2>Sorted Sets</h2><p>Rankingi i sliding window rate limiting w O(log N).</p><h2>Streams</h2><p>XADD/XREAD/XGROUP – lekka alternatywa dla Kafki z consumer groups.</p><h2>Pub/Sub</h2><p>Real-time powiadomienia i invalidacja cache w systemach rozproszonych.</p>','databases',ARRAY['redis','cache','messaging'],'🔴'),
('HAProxy – load balancing dla zaawansowanych','haproxy-load-balancing','ACL, stick tables, health checks i SSL termination w praktyce.','<h2>ACL</h2><p><code>acl is_api path_beg /api/<br>use_backend api_servers if is_api</code></p><h2>Stick Tables</h2><p><code>stick-table type ip size 1m expire 10s store conn_rate(10s)</code><br>Session persistence i rate limiting bez zewnętrznych narzędzi.</p><h2>Health Checks</h2><p>Aktywne testy TCP/HTTP – automatyczne wykluczanie padniętych backendów.</p>','networking',ARRAY['haproxy','loadbalancer','networking'],'⚖️'),
('Nginx – reverse proxy i SSL/TLS','nginx-reverse-proxy-ssl','Let Encrypt, HTTP/2, security headers – kompletna konfiguracja.','<h2>Reverse proxy</h2><p><code>location / { proxy_pass http://app:3000; proxy_set_header Host $host; }</code></p><h2>SSL</h2><p><code>certbot --nginx -d example.com</code> – automatyczne certyfikaty i odnawianie.</p><h2>Security headers</h2><p>HSTS, X-Frame-Options, X-Content-Type-Options, CSP.</p>','networking',ARRAY['nginx','ssl','security'],'🌿'),
('GitOps z Flux CD','gitops-flux-cd','Source, Kustomize, Helm Controller – GitOps w Kubernetes od A do Z.','<h2>Architektura</h2><p>Source Controller obserwuje Git/Helm, Kustomize Controller aplikuje manifesty, Helm Controller zarządza releases.</p><h2>Reconciliation loop</h2><p>Flux ciągle porównuje stan klastra ze stanem w repozytorium i koryguje odchylenia.</p><h2>Image Automation</h2><p>Automatyczna aktualizacja tagów Docker po pojawieniu się nowego obrazu w registry.</p>','devops',ARRAY['gitops','kubernetes','flux'],'🔄'),
('Zabbix – monitoring od zera','zabbix-monitoring','Agenty, szablony, triggery i alerty w Zabbix 6.x.','<h2>Protokoły</h2><p>Zabbix Agent (aktywny/pasywny), SNMP, IPMI, JMX, HTTP checks.</p><h2>Templates</h2><p>Gotowe szablony dla Linux, Windows, PostgreSQL, MySQL, Nginx, Docker i setek innych.</p><h2>Alerty</h2><p>Email, Slack, PagerDuty, Microsoft Teams. Akcje mogą też automatycznie restartować usługi.</p>','devops',ARRAY['zabbix','monitoring','infrastructure'],'📊'),
('ModSecurity + OWASP CRS na Nginx','modsecurity-waf','WAF chroniący przed SQL Injection, XSS i OWASP Top 10 – instalacja krok po kroku.','<h2>ModSecurity</h2><p>Open-source WAF jako moduł Nginx: <code>apt install libnginx-mod-http-modsecurity</code>.</p><h2>OWASP CRS</h2><p>Core Rule Set to zestaw reguł pokrywający SQL Injection, XSS, LFI, RFI, RCE.</p><h2>Tryby</h2><p><strong>DetectionOnly</strong> – loguj, nie blokuj (tuning). <strong>On</strong> – aktywna ochrona produkcyjna.</p>','security',ARRAY['modsecurity','waf','security','nginx'],'🛡️'),
('IPSec VPN site-to-site ze Strongswan','ipsec-vpn-site-to-site','IKEv2, PSK, integracja z Fortigate – kompletny przewodnik.','<h2>Fazy IPSec</h2><p>Phase 1 – ISAKMP SA (auth PSK/cert). Phase 2 – IPSec SA (tunel danych).</p><h2>Strongswan</h2><p>Konfiguracja w <code>/etc/ipsec.conf</code>: lokalne/zdalne IP, sieci, algorytmy AES256-SHA256-DH14.</p><h2>Fortigate</h2><p>Identyczne proposal po obu stronach tunelu, PSK lub wzajemne certyfikaty X.509.</p>','security',ARRAY['ipsec','vpn','security','fortigate'],'🔐')
ON CONFLICT(slug) DO NOTHING;

-- SEED

-- Usuń stare seed artykuły i dodaj nowe
DELETE FROM articles WHERE is_published = true;

INSERT INTO articles (title, slug, excerpt, content, category, tags, cover_emoji, is_published) VALUES

('AWS DevOps Agent i Security Agent — ogólna dostępność od kwietnia 2026',
 'aws-devops-security-agent-ga-2026',
 'Amazon oficjalnie udostępnił dwa autonomiczne agenty AI: DevOps Agent i Security Agent. Działają bez nadzoru człowieka, wykrywają incydenty i testują penetracyjnie infrastrukturę w czasie rzeczywistym.',
 'Amazon Web Services ogłosiło w kwietniu 2026 roku ogólną dostępność (GA) dwóch przełomowych agentów AI: AWS DevOps Agent oraz AWS Security Agent.

AWS DevOps Agent automatyzuje operacje chmurowe — bada incydenty, skraca czas ich rozwiązywania i zapobiega problemom zanim się pojawią. Działa autonomicznie na infrastrukturze AWS, multicloud oraz on-prem.

AWS Security Agent to ciągłe, kontekstowe testy penetracyjne wbudowane w cykl wytwarzania oprogramowania. Działa jak doświadczony pentester — skanuje podatności w kontekście całej architektury, a nie tylko izolowanych komponentów. Według danych LG CNS wdrożenie agenta przyspieszyło testy o ponad 50% i obniżyło koszty o ~30%.

Oba agenty są częścią nowej kategorii "frontier agents" zaprezentowanej na AWS re:Invent i integrują się z Amazon Bedrock AgentCore — środowiskiem do budowania i wdrażania agentów AI klasy enterprise.

Kluczowe możliwości:
- Automatyczna analiza przyczyn źródłowych (RCA) incydentów
- Proaktywne wykrywanie anomalii przed ich eskalacją  
- Integracja z CloudWatch, ECS, EKS i środowiskami hybrydowymi
- Raportowanie zgodności i zarządzanie podatnościami',
 'DevOps', ARRAY['AWS','AI','Agenty','DevSecOps','Cloud'], '🤖', true),

('Gartner: 10 strategicznych trendów technologicznych na 2026 rok',
 'gartner-top-10-trendow-2026',
 'Analitycy Gartnera wskazują 2026 jako rok przełomu AI w infrastrukturze, bezpieczeństwie i automatyzacji. W centrum: agentyczne AI, platformy no-code generujące kod i intent-driven infrastructure.',
 'Podczas konferencji Gartner IT Symposium/Xpo analitycy przedstawili 10 trendów, które będą kształtować IT w 2026 roku. Wspólnym mianownikiem niemal wszystkich jest sztuczna inteligencja wkraczająca w kolejne warstwy infrastruktury.

1. Agentyczne AI w operacjach IT — systemy samodzielnie planujące i wykonujące zadania operacyjne bez interwencji człowieka.

2. Platformy low-code/no-code z GenAI — generowanie kodu aplikacyjnego z opisu w języku naturalnym. Gartner szacuje, że do końca 2026 roku ponad 70% nowych aplikacji wewnętrznych powstanie bez tradycyjnego programowania.

3. Intent-driven infrastructure — zamiast pisać IaC (Terraform, Ansible), zespoły definiują pożądany stan infrastruktury, a platforma sama dobiera zasoby i konfiguruje zgodność.

4. AI w cyberbezpieczeństwie — predykcyjne zarządzanie podatnościami, które naprawia luki zanim skanery je wykryją.

5. Sovereign cloud i tech sovereignty — Europa przyspiesza budowę własnych chmur i regulacji AI Act wymuszających lokalne przetwarzanie danych.

6. Robotyka operacyjna sterowana AI — fizyczne procesy produkcyjne integrowane z systemami AI w czasie rzeczywistym.

7. Kwantowe bezpieczeństwo — migracja algorytmów kryptograficznych na post-quantum standards (NIST PQC).

8. Edge AI — modele językowe działające lokalnie na urządzeniach IoT bez połączenia z chmurą.

9. Sustainability computing — mierzenie i optymalizacja śladu węglowego infrastruktury IT (AWS Sustainability Console Scope 1-3).

10. Digital immune systems — wielowarstwowe systemy odporności aplikacji łączące observability, chaos engineering i AI.',
 'AI', ARRAY['Gartner','AI','Trendy','2026','Infrastruktura'], '📊', true),

('DevSecOps w 2026: AI zastępuje shift-left, nadchodzi predictive security',
 'devsecops-ai-predictive-2026',
 'Shift-left to już przeszłość. W 2026 roku liderzy DevSecOps wdrażają AI-driven SAST/SCA z rozumieniem kontekstu i predykcyjne zarządzanie podatnościami — naprawiają luki zanim skaner je znajdzie.',
 'Koncepcja shift-left — przesuwanie testów bezpieczeństwa wcześniej w pipeline — przez lata była złotym standardem DevSecOps. W 2026 roku to już minimum, punkt wyjścia a nie wyróżnik.

Liderzy przechodzą na model predictive security:

AI-driven SAST i SCA z kontekstem
Tradycyjne narzędzia statycznej analizy generują setki fałszywych alarmów. Nowa generacja (np. Snyk DeepCode AI, GitHub Advanced Security z Copilot) rozumie semantykę kodu i architekturę aplikacji — redukując false positives o 60-80%.

Software Supply Chain Security jako baseline
SBOM (Software Bill of Materials) stały się wymogiem regulacyjnym w USA (EO 14028) i de facto standardem w Europie. Narzędzia jak Sigstore, SLSA i Guac automatycznie podpisują i weryfikują każdy artefakt w pipeline.

Predykcyjne zarządzanie podatnościami
Systemy analizują wzorce commitów, historię podatności bibliotek i kontekst deploymentu aby przewidzieć które komponenty będą podatne — zanim CVE zostanie opublikowane.

Platform engineering jako fundament
Centralne platformy wewnętrzne (Internal Developer Platforms) wymuszają security by default: każdy nowy serwis startuje z pre-approved baseline zawierającym polityki sieciowe, skanowanie obrazów i rotację sekretów.

65% przedsiębiorstw doświadczyło w 2025 roku incydentów związanych z agentami AI wynikających ze słabego governance i braku widoczności — to główny driver inwestycji w AI SOC w 2026.',
 'Bezpieczeństwo', ARRAY['DevSecOps','AI','Security','SAST','Pipeline'], '🔐', true),

('GitOps z ArgoCD i Flux staje się standardem w Kubernetes 2026',
 'gitops-argocd-flux-standard-2026',
 'GitOps dojrzał — ArgoCD i Flux to już nie eksperyment, lecz fundament CD w środowiskach Kubernetes. Git jako single source of truth zmienia model operacyjny całych platform teams.',
 'GitOps to podejście do zarządzania infrastrukturą i aplikacjami gdzie Git jest jedynym źródłem prawdy (single source of truth). Każda zmiana w infrastrukturze przechodzi przez pull request — z pełną historią, code review i możliwością rollbacku jedną komendą.

Dlaczego GitOps wygrał?

W środowiskach Kubernetes ręczne kubectl apply szybko staje się problemem w skali. Przy dziesiątkach klastrów i setkach serwisów potrzebny jest mechanizm który:
- Gwarantuje że klaster zawsze odpowiada temu co jest w repo (reconciliation loop)
- Wykrywa i naprawia drift konfiguracji automatycznie
- Daje pełen audit trail każdej zmiany
- Umożliwia rollback do dowolnego punktu w historii

ArgoCD vs Flux w 2026

ArgoCD dominuje w dużych organizacjach dzięki rozbudowanemu UI, RBAC i multi-cluster management. Flux wybierają zespoły preferujące podejście operator-native bez centralnego serwera.

Nowe możliwości w 2026:
- Flux 2.3 wprowadził natywne wsparcie dla OCI artifacts
- ArgoCD ApplicationSet automatyzuje onboarding nowych klastrów
- Oba narzędzia integrują się z Crossplane do zarządzania zasobami cloudowymi przez GitOps

Praktyczny tip: zdefiniuj strukturę repo jako monorepo z katalogami per środowisko (dev/staging/prod) i per klaster. Używaj Kustomize do nakładania różnic środowiskowych zamiast Helm values dla prostszych workloadów.',
 'DevOps', ARRAY['GitOps','Kubernetes','ArgoCD','Flux','CD'], '⚙️', true),

('Agenty AI atakują chmurę — Unit 42 potwierdza functional maturity',
 'ai-cloud-attacks-unit42-2026',
 'Proof-of-concept Unit 42 udowodnił że agenty AI potrafią samodzielnie przeprowadzić pełny łańcuch ataku: rekonesans, eksploitację, eskalację uprawnień i eksfiltrację danych — bez udziału człowieka.',
 'Raport Unit 42 (Palo Alto Networks) z kwietnia 2026 roku przynosi niepokojące wnioski: ataki z użyciem agentów AI osiągnęły "functional maturity" — dojrzałość operacyjną pozwalającą na przeprowadzenie kompletnych kampanii ataków bez ludzkiego operatora.

Co pokazał proof-of-concept?

Agnostic model PoC (niezależny od konkretnego LLM) był w stanie samodzielnie:
1. Przeprowadzić rekonesans środowiska chmurowego (AWS/Azure/GCP)
2. Zidentyfikować podatne usługi i misconfiguracje
3. Wyeksploitować podatności aby uzyskać dostęp
4. Eskalować uprawnienia do poziomu cloud admin
5. Wykonać eksfiltrację danych

Całość bez jednej linii kodu pisanej przez człowieka w czasie ataku.

Skala problemu

65% przedsiębiorstw doświadczyło incydentów bezpieczeństwa związanych z agentami AI w 2025 roku — głównie przez brak governance i widoczności nad tym co agenty robią w systemach produkcyjnych.

Jak się bronić?

- Implementuj least-privilege dla każdego agenta AI (osobne service accounts)
- Loguj i monitoruj WSZYSTKIE akcje agentów (nie tylko wyniki)
- Używaj network segmentation — agent nie powinien mieć dostępu do całej sieci
- Wprowadź human-in-the-loop dla akcji wysokiego ryzyka (usuwanie danych, zmiany IAM)
- Regularnie audytuj uprawnienia agentów jak regularnych użytkowników

Platform engineers muszą zarządzać agentami AI jak krytyczną infrastrukturą — z pełną kontrolą tożsamości, polityk i observability.',
 'Bezpieczeństwo', ARRAY['AI','Security','Cloud','Ataki','Unit42'], '⚠️', true),

('PostgreSQL 17 — co nowego w najnowszym wydaniu bazy danych',
 'postgresql-17-nowe-funkcje',
 'PostgreSQL 17 wprowadza znaczące usprawnienia w wydajności VACUUM, nowy streaming checkpoint, ulepszone JSON_TABLE oraz wsparcie dla merge joins w więcej przypadkach. Przegląd najważniejszych zmian.',
 'PostgreSQL pozostaje najpopularniejszą zaawansowaną otwartą bazą danych na świecie. Wersja 17 przynosi szereg usprawnień szczególnie istotnych dla środowisk produkcyjnych wysokiej skali.

Wydajność VACUUM
VACUUM w PostgreSQL 17 jest znacząco szybszy dzięki nowej strategii przetwarzania stron. Wprowadzono "eager freezing" — mechanizm który proaktywnie zamraża krotki podczas normalnego VACUUM zamiast czekać na VACUUM FREEZE. Efekt: rzadsze pełne VACUUM i mniejszy wpływ na wydajność produkcyjną.

Streaming Checkpoint
Nowy mechanizm checkpointów zmniejsza spikes I/O podczas zapisu WAL. Zamiast zapisywać wszystkie dirty pages naraz, PostgreSQL 17 rozkłada zapis równomiernie w czasie checkpoint interval. Szczególnie istotne dla środowisk z dużymi buforami shared_buffers.

Ulepszenia JSON
JSON_TABLE — standardowy SQL/JSON operator — jest teraz w pełni zaimplementowany zgodnie ze specyfikacją SQL:2016. Pozwala na przetwarzanie dokumentów JSON jak tabel relacyjnych bezpośrednio w zapytaniach SQL.

Nowe funkcje okienkowe
Rozszerzono wsparcie dla MERGE z klauzulą RETURNING — można teraz sprawdzić co dokładnie zostało wstawione, zaktualizowane lub usunięte w operacji MERGE.

Logiczne replikacja
Subskrypcje logiczne mogą teraz replikować sekwencje — rozwiązuje długoletni problem z migracją primary keys do replik w architekturach active-active.

Praktyczne wskazówki dla DBA:
Po upgrade uruchom ANALYZE na wszystkich tabelach. Sprawdź czy autovacuum settings są dostosowane do nowych domyślów. Przetestuj wydajność zapytań z JSON_TABLE na swoich danych przed migracją produkcji.',
 'Bazy danych', ARRAY['PostgreSQL','Bazy danych','SQL','Performance','DBA'], '🐘', true),

('Kubernetes 1.32 — Sidecar containers stabilne, co jeszcze nowego?',
 'kubernetes-1-32-sidecar-stable',
 'Kubernetes 1.32 stabilizuje sidecar containers jako oficjalną funkcję oraz wprowadza ulepszone zarządzanie zasobami dla GPU workloadów, nowe polityki sieciowe i ulepszony scheduler.',
 'Kubernetes 1.32 to kolejne wydanie otwartej platformy orkiestracji kontenerów, które przynosi kilka istotnych zmian dla inżynierów platform i DevOps.

Sidecar Containers — stabilne (GA)
Po dwóch latach w fazie beta, sidecar containers osiągają status Generally Available. Sidecar jako dedykowany typ kontenera (initContainer z restartPolicy: Always) rozwiązuje problemy z:
- Kolejnością startu (sidecar zawsze startuje przed głównym kontenerem)
- Zakończeniem (sidecar kończy się po głównym kontenerze)
- Graceful shutdown całego Poda

To fundamentalna zmiana dla service mesh (Istio, Linkerd), logging agents i security proxies.

Ulepszone zarządzanie GPU
Dynamic Resource Allocation (DRA) dla GPU wychodzi z alpha. Pozwala na współdzielenie GPU między Podami i dynamiczne przydzielanie frakcji GPU — kluczowe dla efektywnego wykorzystania drogiego sprzętu AI/ML.

Network Policies v2 (beta)
Nowe API dla polityk sieciowych z obsługą:
- Reguł egress dla zewnętrznych endpointów (CIDR + port + protokół)
- Named ports w NetworkPolicy
- Wildcardów w namespace selector

Scheduler improvements
Nowy plugin schedulera "NodeInclusionPolicy" pozwala kontrolować jak tainted nodes są traktowane przy obliczaniu skewed workloads — rozwiązuje edge cases w topologySpreadConstraints.

Deprecations
- dockershim został usunięty kilka wersji temu, ale 1.32 usuwa ostatnie referencje
- In-tree cloud provider plugins (AWS, GCP, Azure) są teraz w pełni zastąpione zewnętrznymi CCM',
 'DevOps', ARRAY['Kubernetes','Kontenery','Sidecar','GPU','K8s'], '☸️', true),

('Quantum-safe cryptography: NIST finalizuje standardy post-kwantowe',
 'nist-post-quantum-standards-2026',
 'NIST opublikował finalne standardy kryptografii post-kwantowej: ML-KEM (CRYSTALS-Kyber), ML-DSA (CRYSTALS-Dilithium) i SLH-DSA (SPHINCS+). Czas na migrację — komputery kwantowe zbliżają się do poziomu cryptographically relevant.',
 'NIST (National Institute of Standards and Technology) zakończył wieloletni proces standaryzacji algorytmów kryptografii post-kwantowej. Publikacja finalnych standardów FIPS 203, 204 i 205 uruchamia globalną migrację systemów kryptograficznych.

Dlaczego teraz?

Komputery kwantowe zbliżają się do poziomu "cryptographically relevant quantum computer" (CRQC) — maszyny zdolnej złamać RSA-2048 i ECC w czasie praktycznym. Eksperci szacują, że CRQC może powstać w perspektywie 5-15 lat.

Paradoks "harvest now, decrypt later" sprawia, że migracja musi rozpocząć się DZIŚ — atakujący zbierają zaszyfrowane dane teraz, planując ich odszyfrowanie po pojawieniu się CRQC.

Nowe standardy:

ML-KEM (FIPS 203) — Key Encapsulation Mechanism oparty na CRYSTALS-Kyber. Zastępuje RSA i ECDH w wymianie kluczy. Szybszy od RSA, klucze ~1KB.

ML-DSA (FIPS 204) — Digital Signature Algorithm oparty na CRYSTALS-Dilithium. Zastępuje ECDSA i RSA signatures. Podpisy ~2.4KB.

SLH-DSA (FIPS 205) — hash-based signatures (SPHINCS+). Konzerwatywna alternatywa oparta wyłącznie na bezpieczeństwie funkcji skrótu.

Jak zacząć migrację?

1. Inwentaryzacja — zidentyfikuj wszystkie miejsca gdzie używasz RSA, ECC, DH
2. Crypto-agility — refaktoryzuj kod aby algorytm był konfigurowalny (nie hardcoded)
3. Hybrid mode — wdróż równolegle klasyczny + post-kwantowy algorytm (np. X25519+Kyber)
4. Priorytetyzacja — zacznij od danych o długim okresie tajności (dokumenty rządowe, dane medyczne)

TLS 1.3 już wspiera hybrydowe grupy key exchange. OpenSSL 3.x i BouncyCastle mają implementacje CRYSTALS.',
 'Bezpieczeństwo', ARRAY['Kryptografia','Post-quantum','NIST','Security','Szyfrowanie'], '🔑', true),

('FinOps 2026: jak AI pomaga ciąć koszty chmury o 40%',
 'finops-ai-cloud-cost-2026',
 'Narzędzia FinOps nowej generacji używają AI do przewidywania zużycia zasobów, automatycznego rightsizingu i wykrywania anomalii kosztowych. Średnie oszczędności w enterprise: 30-40% rachunku za chmurę.',
 'Zarządzanie kosztami chmury (FinOps) weszło w nową erę — zamiast manualnych raportów i arkuszy Excel, zespoły używają AI do automatycznej optymalizacji wydatków.

Problem skali

Przeciętna organizacja enterprise używa 3-5 dostawców chmury i generuje miliony zdarzeń billing dziennie. Ręczna analiza jest niemożliwa — stąd rosnąca rola AI w FinOps.

Co robi AI w FinOps?

Predictive rightsizing
Modele ML analizują historyczne użycie CPU, pamięci i sieci aby rekomendować optymalny rozmiar instancji. Narzędzia jak AWS Compute Optimizer, Google Active Assist i Azure Advisor przeszły w 2025-2026 z rekomendacji na automatyczne akcje (z zatwierdzeniem lub bez).

Anomaly detection
Automatyczne wykrywanie nagłych wzrostów kosztów zanim pojawią się na rachunku. Systemy uczą się normalnych wzorców i alertują przy odchyleniach >2σ — często wykrywając błędy konfiguracji zanim staną się kosztowne.

Spot/Preemptible optimization
AI przewiduje prawdopodobieństwo przerwania instancji spot i automatycznie migruje workloady między typami instancji i regionami dla maksymalizacji oszczędności przy zachowaniu SLA.

Kubernetes cost allocation
Granularne przypisanie kosztów K8s do teamów/aplikacji/projektów — dotychczasowy problem szczególnie w multi-tenant klastrach. Narzędzia jak Kubecost i OpenCost integrują się teraz z wewnętrznymi systemami chargeback.

Wyniki w praktyce

Według raportu Flexera 2026 Cloud Report:
- 82% organizacji ma "significant" cloud waste
- Mediana oszczędności po wdrożeniu FinOps AI: 32%
- Top 25% organizacji osiąga >40% redukcji kosztów

Kluczowe narzędzia 2026: AWS Cost Explorer + Compute Optimizer, Google Cloud Cost Management, Azure Cost Management + Advisor, Cloudability, Apptio Cloudability, Kubecost.',
 'DevOps', ARRAY['FinOps','Cloud','Koszty','AI','Kubernetes'], '💰', true),

('Edge AI: modele językowe działające lokalnie bez chmury',
 'edge-ai-local-llm-2026',
 'Llama 3, Mistral i Phi-3 działają na smartfonach, routerach i urządzeniach IoT. Edge AI eliminuje latencję, koszty API i obawy o prywatność — otwierając nowe zastosowania niedostępne dla cloud AI.',
 'Rok 2026 to rok gdy AI naprawdę opuściło chmurę. Modele językowe działają teraz lokalnie na telefonach, laptopach, urządzeniach przemysłowych i routerach — bez żadnego połączenia z zewnętrznym API.

Co umożliwiło tę zmianę?

Quantization — technika kompresji modeli (INT4, INT8, GGUF) zmniejszyła wymagania pamięciowe 4-8x przy zachowaniu ~95% jakości. Model który wymagał 80GB VRAM działa teraz na 8GB RAM.

Dedykowane jednostki NPU (Neural Processing Unit) w nowoczesnych SoC — Apple M4, Qualcomm Snapdragon X Elite, AMD Ryzen AI — osiągają 45-60 TOPS (Trillion Operations Per Second).

Efektywne architektury jak Microsoft Phi-3-mini (3.8B parametrów) dorównują jakością GPT-3.5 w wielu zadaniach przy ułamku rozmiaru.

Zastosowania Edge AI w 2026:

Przemysł (Industrial Edge)
Wizja maszynowa i anomaly detection na liniach produkcyjnych bez wysyłania obrazów do chmury. Latencja <10ms niemożliwa przy cloud API.

Medycyna
Analiza EKG, zdjęć RTG i danych z wearables lokalnie na urządzeniu — GDPR/HIPAA compliance bez skomplikowanej architektury.

Sieci i bezpieczeństwo
Router/firewall z lokalnym LLM analizującym ruch sieciowy i wykrywającym anomalie bez wysyłania logów do zewnętrznej usługi.

Automotive
Asystenci głosowi i systemy ADAS działające w tunelach i obszarach bez zasięgu.

Narzędzia dla deweloperów:
- Ollama — uruchamianie modeli lokalnie jedną komendą
- llama.cpp — C++ runtime zoptymalizowany pod CPU
- Apple MLX — framework dla Apple Silicon
- ONNX Runtime — deployment na dowolnym sprzęcie',
 'AI', ARRAY['Edge AI','LLM','IoT','Prywatność','Embedded'], '🤖', true);
