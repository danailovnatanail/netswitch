# NetSwitch (macOS, Apple Silicon)

Porting della versione Windows per macOS: pannello compatto in stile "flyout" per gestire le
interfacce di rete, ancorato all'icona di NetSwitch nella barra dei menu. Per il momento
supporta solo Mac con processore Apple Silicon (arm64).

> Questa versione non è stata ancora compilata né testata su un Mac reale: è stata scritta
> in un ambiente Linux senza accesso a macOS. Vedi "Stato e limiti noti" più sotto.

## Uso
- **Clic sinistro sull'icona** → apre/chiude il pannello (si chiude anche cliccando altrove o
  con Esc).
- **Clic destro sull'icona** → menu rapido: interfacce, configurazioni salvate, avvio
  automatico, esci.
- Rilanciare l'app mentre è già attiva riapre il pannello.

Il pannello segue il tema chiaro/scuro e il colore d'accento di macOS e si posiziona appena
sotto l'icona nella barra dei menu (che su macOS è sempre in alto, a differenza della taskbar
di Windows che può stare sopra o sotto).

## Funzioni
Le stesse della versione Windows:
- **Interfacce**: raggruppate in *Connesse*, *Non connesse* e *Disattivate*. Per ognuna: IP,
  modalità DHCP/Statico e interruttore per attivarle/disattivarle (chiede conferma prima di
  disattivare). Clic sulla scheda per i dettagli (gateway, DNS, MAC, velocità): clic su un
  valore = copia negli appunti.
- **Imposta IP**: formato `IP/prefisso` o `IP/subnetmask` (es. `192.168.1.10/24`), più
  indirizzi separati da virgola. Gateway e DNS facoltativi.
- **DHCP**: indirizzo e DNS automatici.
- **Configurazioni salvate**: crea, modifica, duplica, riordina, elimina; applicabili a
  qualsiasi interfaccia dal pannello o dal menu del tasto destro. File:
  `~/Library/Application Support/NetSwitch/configurazioni.xml` (stesso formato XML della
  versione Windows: i file sono intercambiabili tra le due piattaforme).
- **Avvia con il Mac** (menu ⋯): LaunchAgent utente (`~/Library/LaunchAgents`), equivalente
  macOS dell'attività pianificata di Windows.

## Differenza principale rispetto a Windows: privilegi amministrativi
Windows chiede i privilegi di amministratore una sola volta all'avvio (UAC) e poi esegue tutte
le operazioni di rete senza altri prompt. Su macOS non esiste un equivalente diretto senza
un helper privilegiato firmato con certificato Apple Developer (infrastruttura non disponibile
in questo contesto di sviluppo). Questa versione quindi:
- Esegue **ogni singola operazione** che modifica la rete (IP statico, DHCP, attiva/disattiva
  interfaccia) tramite `osascript ... with administrator privileges`, che mostra il prompt
  nativo della password di amministratore di macOS — l'equivalente concettuale di UAC, ma per
  singola operazione invece che una volta sola all'avvio. macOS spesso non richiede la
  password più volte a distanza di pochi minuti.
- Le letture (stato delle interfacce, IP, DNS) **non richiedono** privilegi elevati.

## Compilazione
Serve solo Xcode oppure gli Strumenti da riga di comando di Xcode (per `swiftc`):

    xcode-select --install   # se non già installati
    ./build.sh

Produce `NetSwitch.app` nella cartella corrente, compilato per arm64 (Apple Silicon) e firmato
ad-hoc (senza certificato Apple Developer: al primo avvio macOS potrebbe chiedere conferma in
Preferenze di Sistema → Privacy e Sicurezza → "Apri comunque").

Diagnostica: con `NETSWITCH_DEBUG=1` viene scritto `$TMPDIR/netswitch_debug.log` (stessa
convenzione della versione Windows: `NETSWITCH_FAKE=1`, `NETSWITCH_DEMO=...`,
`NETSWITCH_SNAP=file.png`, `NETSWITCH_THEME=dark|light`, `NETSWITCH_NOHIDE=1`).

## Stato e limiti noti (rispetto alla fedeltà all'originale Windows)
Elenco onesto delle semplificazioni introdotte per i vincoli di questo ambiente di sviluppo
(nessun Mac disponibile per compilare/testare) e per le differenze intrinseche tra le due
piattaforme:

- **Non compilato/testato**: il codice è stato scritto con attenzione ma non verificato con un
  compilatore Swift reale né eseguito su macOS. Vanno previsti aggiustamenti in fase di prima
  compilazione.
- **Indirizzi IP multipli per interfaccia**: Windows li persiste tramite `netsh ... add
  address`. Su macOS, `networksetup` non supporta più indirizzi sulla stessa interfaccia:
  l'indirizzo principale viene impostato con `networksetup -setmanual` (persistente), gli
  indirizzi aggiuntivi con `ifconfig ... alias` (**non persistono dopo un riavvio**).
- **Velocità del Wi-Fi**: non mostrata (su Windows disponibile via NDIS; su macOS richiederebbe
  API private o strumenti deprecati).
- **Cambio tema a caldo**: le schede delle interfacce/configurazioni si aggiornano al
  ricalcolo periodico (ogni 5 secondi col pannello aperto); gli elementi fissi del pannello
  (sfondo, pulsanti, intestazione) si aggiornano la volta successiva che il pannello viene
  aperto, non istantaneamente come su Windows (che usa `DynamicResource` di WPF).
  Attualmente **non testato**.
- **Animazioni**: semplificate a semplici dissolvenze (fade), invece delle dissolvenze +
  scorrimento della versione WPF, per maggiore affidabilità con AppKit senza possibilità di
  verifica visiva diretta in questo ambiente.
- **Notifiche di sistema**: usa l'API storica `NSUserNotification` (deprecata da Apple a
  favore di `UserNotifications`, che richiede però firma/autorizzazioni non disponibili qui).
- **"Nascondi quando perde il focus"**: il pannello si chiude quando la finestra perde lo stato
  di finestra chiave (`resignKey`), equivalente a `Deactivated` in WPF. Da verificare che
  l'apertura di un sottomenu (es. "Applica configurazione") non chiuda il pannello per errore.

## Esclusione di responsabilità
NetSwitch è fornito "così com'è", senza garanzie di alcun tipo. Modifica la configurazione di
rete del computer: lo usi a tuo rischio. Lo sviluppatore non è responsabile di danni, perdite
di dati o interruzioni di connettività derivanti dal suo utilizzo.
